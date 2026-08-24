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

@test "a truncated trailing line is skipped, not fatal" {
  run tm_metrics home-a --session 11111111-1111-1111-1111-111111111111 --run wf_bbb2222-222
  [ "$status" -eq 0 ]
  [ "$(tm_field "$output" runs.0.agents.0.out)" = "300" ]
  [ "$(tm_field "$output" runs.0.agents.0.tools)" = "1" ]
}

@test "started without result means running, and type comes from meta" {
  run tm_metrics home-a --session 11111111-1111-1111-1111-111111111111 --run wf_bbb2222-222
  [ "$(tm_field "$output" runs.0.agents.0.state)" = "running" ]
  [ "$(tm_field "$output" runs.0.agents.0.agentType)" = "swift-toolkit:swift-developer" ]
}

@test "--run selects exactly one run" {
  run tm_metrics home-a --session 11111111-1111-1111-1111-111111111111 --run wf_bbb2222-222
  [ "$(tm_field "$output" runs.0.runId)" = "wf_bbb2222-222" ]
  [ "$(tm_field "$output" totals.agents)" = "1" ]
}

@test "a session without workflow runs still shows its Task agents" {
  run tm_metrics home-a --session 22222222-2222-2222-2222-222222222222
  [ "$status" -eq 0 ]
  [ "$(tm_field "$output" runs.0.runId)" = "" ]
  [ "$(tm_field "$output" runs.0.agents.0.agentType)" = "swift-toolkit:swift-reviewer" ]
  [ "$(tm_field "$output" runs.0.agents.0.out)" = "512" ]
}

@test "the Task description stands in for a stage name" {
  run tm_metrics home-a --session 22222222-2222-2222-2222-222222222222
  [ "$(tm_field "$output" runs.0.agents.0.phase)" = "Review the diff" ]
}

@test "workflow runs hide Task agents unless --all is passed" {
  run tm_metrics home-a --session 11111111-1111-1111-1111-111111111111
  [ "$(tm_field "$output" totals.agents)" = "3" ]
  run tm_metrics home-a --session 11111111-1111-1111-1111-111111111111 --all
  [ "$(tm_field "$output" totals.agents)" = "3" ]
}

@test "md format prints a table row per agent" {
  run tm_metrics home-a --session 11111111-1111-1111-1111-111111111111 --format md
  [ "$status" -eq 0 ]
  [[ "$output" == *"| Stage | Agent | out | ctx | tools | time |"* ]]
  [[ "$output" == *"| Analyze | swift-architect |"* ]]
  [[ "$output" == *"312.0k"* ]]
}

@test "panel format marks state with a glyph and names the running tool" {
  run tm_metrics home-a --session 11111111-1111-1111-1111-111111111111 --run wf_bbb2222-222 --format panel
  [ "$status" -eq 0 ]
  [[ "$output" == *"🔄"* ]]
  [[ "$output" == *"swift-developer"* ]]
}

@test "an empty document renders its reason instead of a blank screen" {
  run tm_metrics home-empty --session 99999999-9999-9999-9999-999999999999 --format panel
  [ "$status" -eq 0 ]
  [[ "$output" == *"session directory not found"* ]]
}
