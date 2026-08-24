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
  tm_contains "$output" "unknown option"
}

@test "unknown format exits 2" {
  run tm_metrics home-empty --format yaml
  [ "$status" -eq 2 ]
  tm_contains "$output" "unknown format"
}

@test "missing python3 exits 2 with a readable reason" {
  local stub="$(mktemp -d)"
  # /bin/bash by absolute path: with PATH stubbed empty, a `#!/usr/bin/env bash`
  # shebang would fail to resolve its own interpreter before the script runs.
  run env PATH="$stub" CLAUDE_CONFIG_DIR="$(tm_home home-empty)" \
      /bin/bash "$(tm_repo_root)/scripts/agent-metrics.sh"
  [ "$status" -eq 2 ]
  tm_contains "$output" "python3 not found"
}

@test "an option without its value exits 2, not 1" {
  run tm_metrics home-empty --session
  [ "$status" -eq 2 ]
  tm_contains "$output" "missing value for --session"
}

@test "a malformed wf_*.json degrades to an empty result, not a traceback" {
  run tm_metrics home-a --session 33333333-3333-3333-3333-333333333333
  [ "$status" -eq 0 ]
  [ "$(tm_field "$output" reason)" = "could not parse run state" ]
  [ "$(tm_field "$output" runs)" = "[]" ]
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

@test "json carries print-ready strings beside the raw numbers" {
  run tm_metrics home-a --session 11111111-1111-1111-1111-111111111111 --run wf_aaa1111-111
  [ "$status" -eq 0 ]
  [ "$(tm_field "$output" runs.0.agents.0.ctxText)" = "312.0k" ]
  [ "$(tm_field "$output" runs.0.agents.0.elapsedText)" = "1m 04s" ]
  [ "$(tm_field "$output" totals.outText)" = "1.1k" ]
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

@test "a workflowProgress state of progress normalizes to running" {
  run tm_metrics home-a --session 11111111-1111-1111-1111-111111111111 --run wf_ccc3333-333
  [ "$status" -eq 0 ]
  [ "$(tm_field "$output" runs.0.agents.0.state)" = "running" ]
}

@test "a running agent from workflowProgress shows its glyph and tool in the panel" {
  run tm_metrics home-a --session 11111111-1111-1111-1111-111111111111 --run wf_ccc3333-333 --format panel
  [ "$status" -eq 0 ]
  tm_contains "$output" "🔄"
  tm_contains "$output" "Grep"
}

@test "a phase with a running agent shows running, not todo" {
  run tm_metrics home-a --session 11111111-1111-1111-1111-111111111111 --run wf_ccc3333-333
  [ "$(tm_field "$output" runs.0.phases.0.state)" = "running" ]
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

@test "workflow runs hide direct-dispatch agents unless --all is passed" {
  # 11111111... has 3 workflow runs (2 + 1 + 1 agents = 4) plus one direct-dispatch
  # agent (session-level subagents/agent-*.jsonl) that only --all pulls in.
  run tm_metrics home-a --session 11111111-1111-1111-1111-111111111111
  [ "$(tm_field "$output" totals.agents)" = "4" ]
  run tm_metrics home-a --session 11111111-1111-1111-1111-111111111111 --all
  [ "$(tm_field "$output" totals.agents)" = "5" ]
}

@test "the description of an Agent-named dispatch comes through as the phase" {
  run tm_metrics home-a --session 11111111-1111-1111-1111-111111111111 --all
  [ "$status" -eq 0 ]
  [ "$(tm_field "$output" runs.3.agents.0.phase)" = "Write regression tests" ]
  [ "$(tm_field "$output" runs.3.agents.0.agentType)" = "swift-toolkit:swift-tester" ]
}

@test "totals sum across multiple workflow runs of a session, not just the first" {
  # wf_aaa1111-111 out=1148 (2 agents), wf_bbb2222-222 out=300 (1 agent),
  # wf_ccc3333-333 out=150 (1 agent): 1148 + 300 + 150 = 1598, agents 2+1+1 = 4.
  run tm_metrics home-a --session 11111111-1111-1111-1111-111111111111
  [ "$status" -eq 0 ]
  [ "$(tm_field "$output" totals.agents)" = "4" ]
  [ "$(tm_field "$output" totals.out)" = "1598" ]
}

@test "the direct-dispatch pseudo-run derives status and elapsed from its agents" {
  local cfg sess
  cfg="$(mktemp -d)"
  sess="$cfg/projects/-tmp-proj/77777777-7777-7777-7777-777777777777"
  mkdir -p "$sess/subagents"
  cat > "$cfg/projects/-tmp-proj/77777777-7777-7777-7777-777777777777.jsonl" <<'JSON'
{"type":"assistant","timestamp":"2026-08-24T10:00:00.000Z","message":{"model":"claude-opus-5","usage":{"output_tokens":10},"content":[{"type":"tool_use","id":"tu1","name":"Agent","input":{"subagent_type":"swift-toolkit:swift-developer","description":"Patch the bug"}}]}}
{"type":"user","timestamp":"2026-08-24T10:00:01.000Z","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"tu1","content":[{"type":"text","text":"agentId: e0000000000000001"}]}]}}
JSON
  cat > "$sess/subagents/agent-e0000000000000001.jsonl" <<'JSON'
{"type":"assistant","agentId":"e0000000000000001","timestamp":"2026-08-24T10:00:10.000Z","message":{"model":"claude-opus-5","usage":{"input_tokens":1,"output_tokens":50},"content":[{"type":"tool_use","id":"tu2","name":"Edit","input":{}}]}}
JSON
  cat > "$sess/subagents/agent-e0000000000000001.meta.json" <<'JSON'
{"agentType": "swift-toolkit:swift-developer", "spawnDepth": 1}
JSON
  touch "$sess/subagents/agent-e0000000000000001.jsonl"
  run env CLAUDE_CONFIG_DIR="$cfg" CLAUDE_CODE_SESSION_ID=""       "$(tm_repo_root)/scripts/agent-metrics.sh"       --session 77777777-7777-7777-7777-777777777777 --all
  rm -rf "$cfg"
  [ "$status" -eq 0 ]
  [ "$(tm_field "$output" runs.0.agents.0.state)" = "running" ]
  [ "$(tm_field "$output" runs.0.status)" = "running" ]
}

@test "md format prints a table row per agent" {
  run tm_metrics home-a --session 11111111-1111-1111-1111-111111111111 --format md
  [ "$status" -eq 0 ]
  tm_contains "$output" "| Stage | Agent | out | ctx | tools | time |"
  tm_contains "$output" "| Analyze | swift-architect |"
  tm_contains "$output" "312.0k"
}

@test "panel format marks state with a glyph and names the running tool" {
  run tm_metrics home-a --session 11111111-1111-1111-1111-111111111111 --run wf_bbb2222-222 --format panel
  [ "$status" -eq 0 ]
  tm_contains "$output" "🔄"
  tm_contains "$output" "swift-developer"
}

@test "an empty document renders its reason instead of a blank screen" {
  run tm_metrics home-empty --session 99999999-9999-9999-9999-999999999999 --format panel
  [ "$status" -eq 0 ]
  tm_contains "$output" "session directory not found"
}

@test "the panel exits on Ctrl-C and stops painting" {
  export CLAUDE_CODE_SESSION_ID=""
  export CLAUDE_CONFIG_DIR="$(tm_home home-a)"
  run tm_pty_interrupt 2 "$(tm_repo_root)/scripts/agent-monitor.sh" \
      --session 11111111-1111-1111-1111-111111111111 --interval 1
  [ "$status" -eq 0 ]
  [ "$output" = "130 0" ]
}

@test "monitor prints a single snapshot when stdout is not a tty" {
  run env CLAUDE_CONFIG_DIR="$(tm_home home-a)" CLAUDE_CODE_SESSION_ID="" \
      "$(tm_repo_root)/scripts/agent-monitor.sh" \
      --session 11111111-1111-1111-1111-111111111111
  [ "$status" -eq 0 ]
  tm_contains "$output" "swift-architect"
  tm_lacks "$output" $'\033[?1049h'
}
