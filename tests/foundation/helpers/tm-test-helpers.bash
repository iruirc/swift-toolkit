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

# Drives a command under a real pty, sends SIGINT after `wait` seconds, and
# prints "<exit code> <repaints after the interrupt>". Ctrl-C behaviour is the
# one thing about the panel that no ordinary test can see.
tm_pty_interrupt() {
  local wait_s="$1"; shift
  python3 - "$wait_s" "$@" <<'PY'
import os, pty, select, signal, subprocess, sys, time

wait_s = float(sys.argv[1])
master, slave = pty.openpty()
proc = subprocess.Popen(sys.argv[2:], stdout=slave, stderr=slave,
                        stdin=subprocess.DEVNULL, close_fds=True)
os.close(slave)


def drain(seconds):
    out = b""
    end = time.time() + seconds
    while time.time() < end:
        ready, _, _ = select.select([master], [], [], 0.2)
        if ready:
            try:
                out += os.read(master, 65536)
            except OSError:
                break
    return out


drain(wait_s)
proc.send_signal(signal.SIGINT)
after = drain(2.0)
code = proc.poll()
if code is None:
    proc.kill()
    proc.wait()
    code = "running"
print("%s %d" % (code, after.count(b"\x1b[2J")))
PY
}
