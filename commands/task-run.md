---
description: "Run a task from the first unfinished stage / Запустить задачу с первой незавершённой стадии"
argument-hint: <id> [--from <stage>] [--to <stage>]
---

Activate `swift-toolkit:orchestrator` with action=run.

$ARGUMENTS parsing:
- First token — task_id (required)
- `--from <stage>` → start_stage = <stage>
- `--to <stage>` → end_stage = <stage>

If task_id is missing — error using the orchestrator's `error_no_task_id` localized string.

The orchestrator resolves profile, mode, and stack via its Resilient Input Contract. In manual mode it asks for confirmation before starting.
