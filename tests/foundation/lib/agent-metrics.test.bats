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

@test "method A run exposes phases in order" {
  run tm_metrics home-a --session 11111111-1111-1111-1111-111111111111
  [ "$status" -eq 0 ]
  [ "$(tm_field "$output" runs.0.workflow)" = "profile-refactor" ]
  [ "$(tm_field "$output" runs.0.task_id)" = "077" ]
  [ "$(tm_field "$output" runs.0.elapsedMs)" = "252000" ]
  [ "$(tm_field "$output" runs.0.phases.0.title)" = "Analyze" ]
  [ "$(tm_field "$output" runs.0.phases.2.title)" = "Review" ]
}

@test "method A agents carry stage, model, ctx and tool count" {
  run tm_metrics home-a --session 11111111-1111-1111-1111-111111111111
  [ "$(tm_field "$output" runs.0.agents.0.phase)" = "Analyze" ]
  [ "$(tm_field "$output" runs.0.agents.0.agentType)" = "swift-toolkit:swift-architect" ]
  [ "$(tm_field "$output" runs.0.agents.0.model)" = "claude-opus-5" ]
  [ "$(tm_field "$output" runs.0.agents.0.ctx)" = "312000" ]
  [ "$(tm_field "$output" runs.0.agents.0.tools)" = "24" ]
  [ "$(tm_field "$output" runs.0.agents.0.elapsedMs)" = "64000" ]
}

@test "a phase with no agent of its own stays todo" {
  run tm_metrics home-a --session 11111111-1111-1111-1111-111111111111
  [ "$(tm_field "$output" runs.0.phases.0.state)" = "done" ]
  [ "$(tm_field "$output" runs.0.phases.2.state)" = "todo" ]
}

@test "out is summed from the agent transcript, never taken from run state" {
  run tm_metrics home-a --session 11111111-1111-1111-1111-111111111111
  [ "$(tm_field "$output" runs.0.agents.0.out)" = "1148" ]
}

@test "artifact and summary come from the journal result" {
  run tm_metrics home-a --session 11111111-1111-1111-1111-111111111111
  [ "$(tm_field "$output" runs.0.agents.0.artifact)" = "Tasks/ACTIVE/077-refactor-di/Research.md" ]
  [ "$(tm_field "$output" runs.0.agents.0.summary)" = "scope confirmed" ]
}

@test "totals sum out across the agents of a run" {
  run tm_metrics home-a --session 11111111-1111-1111-1111-111111111111 --run wf_aaa1111-111
  [ "$(tm_field "$output" totals.out)" = "1148" ]
  [ "$(tm_field "$output" totals.agents)" = "2" ]
}
