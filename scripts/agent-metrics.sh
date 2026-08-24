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

GLYPH = {"done": "✅", "running": "🔄", "error": "❌",
         "queued": "⬜", "todo": "⬜", "unknown": "⬜"}


def human_tokens(value):
    if not value:
        return "—"
    if value >= 1000000:
        return "%.1fM" % (value / 1000000.0)
    if value >= 1000:
        return "%.1fk" % (value / 1000.0)
    return str(value)


def human_time(value):
    if not value:
        return "—"
    total = int(value // 1000)
    return "%dm %02ds" % (total // 60, total % 60) if total >= 60 else "%ds" % total


def text_fields(record):
    # The JSON consumer would otherwise format milliseconds itself and drift
    # from what the panel shows for the same run.
    return {"outText": human_tokens(record["out"]),
            "ctxText": human_tokens(record["ctx"]),
            "elapsedText": human_time(record["elapsedMs"])}


def short(agent_type):
    return (agent_type or "—").split(":")[-1]


def render_md(doc):
    if not doc["runs"]:
        return doc.get("reason") or "no runs found"
    lines = []
    for run in doc["runs"]:
        head = run["workflow"] or "direct dispatch"
        if run["task_id"]:
            head = "%s · task %s" % (head, run["task_id"])
        lines += ["**%s** — %s · %s" % (head, run["status"] or "—",
                                        human_time(run["elapsedMs"])),
                  "",
                  "| Stage | Agent | out | ctx | tools | time |",
                  "|---|---|---|---|---|---|"]
        for agent in run["agents"]:
            lines.append("| %s | %s | %s | %s | %s | %s |" % (
                agent["phase"] or "—", short(agent["agentType"]),
                human_tokens(agent["out"]), human_tokens(agent["ctx"]),
                agent["tools"] or 0, human_time(agent["elapsedMs"])))
        lines.append("")
    totals = doc["totals"]
    lines.append("%d agents · %s out · %s" % (
        totals["agents"], human_tokens(totals["out"]), human_time(totals["elapsedMs"])))
    return "\n".join(lines)


def render_panel(doc):
    if not doc["runs"]:
        return doc.get("reason") or "no runs found"
    lines = []
    for run in doc["runs"]:
        head = " · ".join(part for part in [
            "task %s" % run["task_id"] if run["task_id"] else None,
            run["workflow"] or "direct dispatch",
            run["status"], human_time(run["elapsedMs"])] if part)
        lines += [head, ""]
        for agent in run["agents"]:
            tail = "  %s" % agent["lastTool"] if agent["state"] == "running" and agent["lastTool"] else ""
            lines.append("  %s %-12s %-18s %7s out · %7s ctx · %3s tools · %8s%s" % (
                GLYPH.get(agent["state"], "⬜"), (agent["phase"] or "—")[:12],
                short(agent["agentType"])[:18], human_tokens(agent["out"]),
                human_tokens(agent["ctx"]), agent["tools"] or 0,
                human_time(agent["elapsedMs"]), tail))
        for phase in run["phases"]:
            if not any(a["phase"] == phase["title"] for a in run["agents"]):
                lines.append("  %s %-12s" % (GLYPH.get(phase["state"], "⬜"),
                                             (phase["title"] or "")[:12]))
        lines.append("")
    totals = doc["totals"]
    lines.append("  %d agents · %s out · %s" % (
        totals["agents"], human_tokens(totals["out"]), human_time(totals["elapsedMs"])))
    return "\n".join(lines)


def emit(doc):
    if FORMAT == "json":
        print(json.dumps(doc, ensure_ascii=False))
    elif FORMAT == "md":
        print(render_md(doc))
    else:
        print(render_panel(doc))
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

import time, calendar


def load_jsonl(path):
    # The last line can be half-written: the file is appended to as we read it.
    rows = []
    try:
        with open(path, encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    rows.append(json.loads(line))
                except ValueError:
                    continue
    except OSError:
        pass
    return rows


def ms(stamp):
    try:
        return calendar.timegm(time.strptime(stamp[:19], "%Y-%m-%dT%H:%M:%S")) * 1000
    except (TypeError, ValueError):
        return None


def transcript(path):
    out = tools = ctx = 0
    model = first = last = None
    for row in load_jsonl(path):
        stamp = row.get("timestamp")
        if stamp:
            first = first or stamp
            last = stamp
        if row.get("type") != "assistant":
            continue
        message = row.get("message") or {}
        model = message.get("model") or model
        usage = message.get("usage") or {}
        out += usage.get("output_tokens") or 0
        # Context is the size of the last request, not a sum over requests.
        ctx = (usage.get("input_tokens", 0)
               + usage.get("cache_creation_input_tokens", 0)
               + usage.get("cache_read_input_tokens", 0)) or ctx
        for block in message.get("content") or []:
            if isinstance(block, dict) and block.get("type") == "tool_use":
                tools += 1
    return {"out": out, "ctx": ctx, "tools": tools, "model": model,
            "first": ms(first), "last": ms(last)}


def meta_type(run_dir, agent_id):
    meta = load_json(os.path.join(run_dir, "agent-%s.meta.json" % agent_id)) or {}
    return meta.get("agentType")


def journal(run_dir):
    started, results = [], {}
    for row in load_jsonl(os.path.join(run_dir, "journal.jsonl")):
        agent_id = row.get("agentId")
        if row.get("type") == "started" and agent_id not in started:
            started.append(agent_id)
        elif row.get("type") == "result":
            results[agent_id] = row.get("result") or {}
    return started, results


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
    seen = transcript(os.path.join(run_dir, "agent-%s.jsonl" % agent_id))
    elapsed = rec.get("durationMs")
    if elapsed is None:
        if state == "running" and epoch(rec.get("startedAt")):
            elapsed = now_ms() - epoch(rec["startedAt"])
        elif seen["first"] and seen["last"]:
            elapsed = seen["last"] - seen["first"]
    record = {
        "agentId": agent_id,
        "agentType": rec.get("agentType") or meta_type(run_dir, agent_id),
        "phase": rec.get("phaseTitle"),
        "model": rec.get("model") or seen["model"],
        "state": state,
        "out": seen["out"],
        "ctx": rec.get("tokens") or seen["ctx"],
        "tools": rec.get("toolCalls") or seen["tools"],
        "elapsedMs": elapsed,
        "lastTool": rec.get("lastToolName"),
        "artifact": None,
        "summary": None,
    }
    record.update(text_fields(record))
    return record


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

    started, results = journal(run_dir)
    if not agents:
        agents = [agent_record(run_dir, agent_id, None,
                               "done" if agent_id in results else "running")
                  for agent_id in started]
    for agent in agents:
        result = results.get(agent["agentId"])
        if result:
            agent["artifact"] = result.get("artifact_path")
            agent["summary"] = result.get("summary")

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


def task_labels(main_transcript):
    """Maps agentId -> the Task call that spawned it, through the tool_use id."""
    calls, links = {}, {}
    for row in load_jsonl(main_transcript):
        for block in ((row.get("message") or {}).get("content") or []):
            if not isinstance(block, dict):
                continue
            if block.get("type") == "tool_use" and block.get("name") == "Task":
                calls[block.get("id")] = block.get("input") or {}
            elif block.get("type") == "tool_result":
                found = re.search(r"agentId: ([0-9a-f]+)",
                                  json.dumps(block.get("content") or "", ensure_ascii=False))
                if found:
                    links[found.group(1)] = block.get("tool_use_id")
    return {agent_id: calls.get(use_id) or {} for agent_id, use_id in links.items()}


def method_b_run(sess):
    directory = os.path.join(sess, "subagents")
    labels = task_labels(sess + ".jsonl")
    agents = []
    for path in sorted(glob.glob(os.path.join(directory, "agent-*.jsonl"))):
        agent_id = os.path.basename(path)[len("agent-"):-len(".jsonl")]
        call = labels.get(agent_id) or {}
        # No journal here: a transcript touched seconds ago is still being written.
        fresh = (now_ms() - int(os.path.getmtime(path) * 1000)) < 30000
        agent = agent_record(directory, agent_id, None, "running" if fresh else "done")
        agent["agentType"] = agent["agentType"] or call.get("subagent_type")
        agent["phase"] = call.get("description")
        agents.append(agent)
    if not agents:
        return None
    return {"runId": None, "workflow": None, "task_id": None, "status": "done",
            "elapsedMs": None, "phases": [], "agents": agents}


runs = []
for path in sorted(glob.glob(os.path.join(sess, "workflows", "wf_*.json"))):
    wf = load_json(path)
    if wf:
        runs.append(build_run(sess, wf))

if RUN_FILTER:
    runs = [r for r in runs if r["runId"] == RUN_FILTER]
elif WANT_ALL or not runs:
    extra = method_b_run(sess)
    if extra:
        runs.append(extra)

totals = {
    "agents": sum(len(r["agents"]) for r in runs),
    "out": sum(a["out"] for r in runs for a in r["agents"]),
    "elapsedMs": sum(r["elapsedMs"] or 0 for r in runs) or None,
}
totals["outText"] = human_tokens(totals["out"])
totals["elapsedText"] = human_time(totals["elapsedMs"])
emit({"session": os.path.basename(sess), "runs": runs, "totals": totals, "reason": None})
PY
