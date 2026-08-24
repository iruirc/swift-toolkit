#!/usr/bin/env bash
set -euo pipefail

# Repaints the collector's panel view in place. Holds no format knowledge of
# its own: everything it shows comes from agent-metrics.sh --format panel.

here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
interval=1
args=()

while [ $# -gt 0 ]; do
  case "$1" in
    --interval) interval="${2:-1}"; shift 2 ;;
    *) args+=("$1"); shift ;;
  esac
done

snapshot() {
  "$here/agent-metrics.sh" --format panel ${args+"${args[@]}"}
}

# Piped or redirected: one snapshot is the whole useful behaviour.
if [ ! -t 1 ]; then
  snapshot
  exit $?
fi

leave() { printf '\033[?1049l'; }
trap leave EXIT INT TERM
printf '\033[?1049h'

while true; do
  printf '\033[H\033[2J'
  snapshot || true
  sleep "$interval"
done
