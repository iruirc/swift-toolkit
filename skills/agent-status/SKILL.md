---
name: agent-status
description: |
  Show agent telemetry for the current session: stage, agent, generated tokens, context size, tool calls and elapsed time. Read-only.
  Use when (en): "agent status", "how many tokens did that cost", "which agents ran", "/swift-agents", "show agent metrics"
  Use when (ru): "статус агентов", "сколько токенов ушло", "какие агенты отработали", "/swift-agents", "покажи метрики агентов"
---

# Agent Status

Read-only snapshot of the agents that ran in this session: stage, agent, generated tokens (`out`), context size (`ctx`), tool calls and elapsed time.

## Language Resolution

Before producing any user-facing string:

1. Read `CLAUDE-swift-toolkit.md` from the project root.
2. Find the `## Language` section.
3. Take the first non-empty line in that section, lowercase and trim it. That is `<lang>`.
4. If `<lang>` is `en` or `ru`, use it. Otherwise default to `en`.
5. Read this skill's `locales/<lang>.md`. Look up keys by H2 header.
6. If a key is missing, fall back to the same key in `locales/en.md`. If still missing, that's a bug — fail loudly with key name.

Caching: resolve `<lang>` once per skill invocation; do not re-read CLAUDE-swift-toolkit.md per string.

## Input

| Argument | Meaning |
|---|---|
| (none) | every workflow run of this session |
| `--run <wf_id>` | one run |
| `--all` | additionally include agents dispatched directly through `Task` |

## Procedure

1. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/agent-metrics.sh" --format md <arguments>`.
2. Exit code 0 — print the header from key `agents_header`, then the script's output verbatim. The table is tool output and stays English; only the header and the notes around it are localized.
3. Exit code 2 — print key `agents_unavailable` with placeholder `{reason}` filled from the script's stderr, and stop. This is not an error worth interrupting anything for.
4. Output containing `no runs found` — print key `agents_none` instead of the empty table.

The script is the only thing that knows where Claude Code keeps its files. Never read `~/.claude` directly from this skill.
