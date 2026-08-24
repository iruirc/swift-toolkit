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

emit({"session": os.path.basename(sess), "runs": [],
      "totals": {"agents": 0, "out": 0, "elapsedMs": None}, "reason": None})
PY
