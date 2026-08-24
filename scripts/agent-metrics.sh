#!/usr/bin/env bash
set -euo pipefail

# The only file in this repo that knows where Claude Code keeps its run state
# and agent transcripts. Those paths are not a public contract: when they move,
# this script is the whole blast radius.

usage() {
  cat <<'USAGE'
usage: agent-metrics.sh [--session <id>] [--run <wf_id>] [--all]
                        [--format json|md|panel]
USAGE
}

session=""
run=""
all=0
format="json"

# Without this guard `shift 2` on a valueless flag trips set -e and exits 1 in
# silence, which is the one failure mode the argument contract forbids.
need_value() {
  [ "$#" -ge 2 ] || { echo "agent-metrics: missing value for $1" >&2; exit 2; }
}

while [ $# -gt 0 ]; do
  case "$1" in
    --session) need_value "$@"; session="$2"; shift 2 ;;
    --run)     need_value "$@"; run="$2"; shift 2 ;;
    --format)  need_value "$@"; format="$2"; shift 2 ;;
    --all)     all=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "agent-metrics: unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

case "$format" in
  json|md|panel) ;;
  *) echo "agent-metrics: unknown format: $format" >&2; exit 2 ;;
esac

if ! command -v python3 >/dev/null 2>&1; then
  echo "agent-metrics: python3 not found — telemetry unavailable" >&2
  exit 2
fi

session="${session:-${CLAUDE_CODE_SESSION_ID:-}}"
config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

python3 - "$config_dir" "$session" "$run" "$format" "$all" <<'PY'
import glob, json, os, re, sys

CONFIG_DIR, SESSION, RUN_FILTER, FORMAT, WANT_ALL = sys.argv[1:6]
WANT_ALL = WANT_ALL == "1"


def emit(doc):
    print(json.dumps(doc, ensure_ascii=False))
    sys.exit(0)


def empty(reason):
    emit({"session": SESSION or None, "runs": [], "totals": None, "reason": reason})


def slug(path):
    return re.sub(r"[^A-Za-z0-9]", "-", path)


def session_dir():
    projects = os.path.join(CONFIG_DIR, "projects")
    if SESSION:
        hits = glob.glob(os.path.join(projects, "*", SESSION))
        return hits[0] if hits else None
    here = os.path.join(projects, slug(os.getcwd()))
    dirs = [p for p in glob.glob(os.path.join(here, "*")) if os.path.isdir(p)]
    return max(dirs, key=os.path.getmtime) if dirs else None


sess = session_dir()
if not sess:
    empty("session directory not found")

import time


def load_json(path):
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return None


def epoch(value):
    # startTime and startedAt are epoch ms in every sample seen; a string is
    # tolerated so a format change degrades to "no time" instead of a crash.
    return int(value) if isinstance(value, (int, float)) else None


def now_ms():
    return int(time.time() * 1000)


def agent_record(run_dir, agent_id, rec, state):
    rec = rec or {}
    elapsed = rec.get("durationMs")
    if elapsed is None and state == "running" and epoch(rec.get("startedAt")):
        elapsed = now_ms() - epoch(rec["startedAt"])
    return {
        "agentId": agent_id,
        "agentType": rec.get("agentType"),
        "phase": rec.get("phaseTitle"),
        "model": rec.get("model"),
        "state": state,
        "out": 0,
        "ctx": rec.get("tokens") or 0,
        "tools": rec.get("toolCalls") or 0,
        "elapsedMs": elapsed,
        "lastTool": rec.get("lastToolName"),
        "artifact": None,
        "summary": None,
    }


def phase_states(phases, agents):
    out = []
    for phase in phases:
        mine = [a for a in agents if a.get("phase") == phase.get("title")]
        if any(a["state"] == "running" for a in mine):
            state = "running"
        elif mine and all(a["state"] in ("done", "error") for a in mine):
            state = "done"
        else:
            state = "todo"
        out.append(dict(phase, state=state))
    return out


def build_run(sess, wf):
    run_id = wf.get("runId") or ""
    run_dir = os.path.join(sess, "subagents", "workflows", run_id)
    progress = wf.get("workflowProgress") or []

    agents = [agent_record(run_dir, r.get("agentId"), r, r.get("state") or "unknown")
              for r in progress if r.get("type") == "workflow_agent"]

    phases = [{"index": p.get("index"), "title": p.get("title")}
              for p in progress if p.get("type") == "workflow_phase"]
    if not phases:
        phases = [{"index": i + 1, "title": (p or {}).get("title")}
                  for i, p in enumerate(wf.get("phases") or [])]

    elapsed = wf.get("durationMs")
    if elapsed is None and epoch(wf.get("startTime")):
        elapsed = now_ms() - epoch(wf["startTime"])

    return {
        "runId": run_id,
        "workflow": wf.get("workflowName"),
        "task_id": (wf.get("args") or {}).get("task_id"),
        "status": wf.get("status"),
        "elapsedMs": elapsed,
        "phases": phase_states(phases, agents),
        "agents": agents,
    }


runs = []
for path in sorted(glob.glob(os.path.join(sess, "workflows", "wf_*.json"))):
    wf = load_json(path)
    if wf:
        runs.append(build_run(sess, wf))

totals = {
    "agents": sum(len(r["agents"]) for r in runs),
    "out": sum(a["out"] for r in runs for a in r["agents"]),
    "elapsedMs": sum(r["elapsedMs"] or 0 for r in runs) or None,
}
emit({"session": os.path.basename(sess), "runs": runs, "totals": totals, "reason": None})
PY
