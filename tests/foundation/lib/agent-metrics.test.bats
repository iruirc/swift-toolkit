#!/usr/bin/env bats
load "$(dirname "$BATS_TEST_FILENAME")/../helpers/tm-test-helpers"

@test "unknown session yields an empty document, not an error" {
  run tm_metrics home-empty --session 99999999-9999-9999-9999-999999999999
  [ "$status" -eq 0 ]
  [ "$(tm_field "$output" reason)" = "session directory not found" ]
  [ "$(tm_field "$output" runs)" = "[]" ]
}

@test "unknown option exits 2" {
  run tm_metrics home-empty --nope
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown option"* ]]
}

@test "unknown format exits 2" {
  run tm_metrics home-empty --format yaml
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown format"* ]]
}

@test "missing python3 exits 2 with a readable reason" {
  local stub="$(mktemp -d)"
  # /bin/bash by absolute path: with PATH stubbed empty, a `#!/usr/bin/env bash`
  # shebang would fail to resolve its own interpreter before the script runs.
  run env PATH="$stub" CLAUDE_CONFIG_DIR="$(tm_home home-empty)" \
      /bin/bash "$(tm_repo_root)/scripts/agent-metrics.sh"
  [ "$status" -eq 2 ]
  [[ "$output" == *"python3 not found"* ]]
}

@test "an option without its value exits 2, not 1" {
  run tm_metrics home-empty --session
  [ "$status" -eq 2 ]
  [[ "$output" == *"missing value for --session"* ]]
}
