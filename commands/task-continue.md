---
description: "Continue a task from the last stop point / Продолжить задачу с точки последней остановки"
argument-hint: <id>
---

Activate `swift-toolkit:orchestrator` with action=continue.

$ARGUMENTS — task_id (required).

The orchestrator reads `Plan.md` (if present), determines the first incomplete phase or stage (via checkboxes / progress table), and resumes from there.
