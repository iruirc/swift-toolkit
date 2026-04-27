# task-move — ru

## error_task_not_found
Задача `{task_id}` не найдена.

## error_invalid_status
Недопустимый статус `{status}`. Разрешены: TODO, ACTIVE, DONE, BACKLOG, RESEARCH, CHECK, UNABLE_FIX (root задачи); плюс PENDING, IN_PROGRESS, DEFERRED, BLOCKED, SKIPPED (step задачи).

## report_moved_root
Задача `{task_id}` перемещена: `{from}` → `{to}`.

## report_moved_step
Шаг `{step_id}` эпика `{parent_id}`: [STATUS] = `{from}` → `{to}`.
