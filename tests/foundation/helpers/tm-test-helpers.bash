#!/usr/bin/env bash
# Shared bats helpers for agent-telemetry tests.
# Source from each .bats file via:
#   load "$(dirname "$BATS_TEST_FILENAME")/../helpers/tm-test-helpers"

tm_repo_root() {
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd
}

# Path to a fixture that stands in for ~/.claude.
tm_home() {
  echo "$(tm_repo_root)/tests/foundation/fixtures/telemetry/$1"
}

# Run the collector against a fixture home instead of the real ~/.claude.
tm_metrics() {
  local home="$1"; shift
  CLAUDE_CONFIG_DIR="$(tm_home "$home")" CLAUDE_CODE_SESSION_ID="" \
    "$(tm_repo_root)/scripts/agent-metrics.sh" "$@"
}

# Read a dotted path out of the collector's JSON:
#   tm_field "$output" runs.0.agents.0.out
tm_field() {
  python3 -c '
import json, sys
node = json.loads(sys.argv[1])
for key in sys.argv[2].split("."):
    node = node[int(key)] if key.isdigit() else node[key]
print("" if node is None else node)
' "$1" "$2"
}

# A failing `[[ ]]` anywhere but the last line of a test does NOT trip bats'
# set -e, so it asserts nothing. Every substring check goes through these.
tm_contains() {
  case "$1" in (*"$2"*) return 0 ;; esac
  echo "expected output to contain: $2" >&2
  return 1
}

tm_lacks() {
  case "$1" in (*"$2"*) echo "expected output NOT to contain: $2" >&2; return 1 ;; esac
  return 0
}
