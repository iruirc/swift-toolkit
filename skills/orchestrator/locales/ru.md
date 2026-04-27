# orchestrator — ru

## error_no_task_id
Укажи номер задачи, например `запусти 026` / `/task-run 026`.

## error_task_not_found
Задача `{task_id}` не найдена в `Tasks/`.

## fallback_profile_question
Какой профиль? (1) FEATURE (2) BUG (3) REFACTOR (4) TEST (5) REVIEW (6) EPIC

## confirm_dispatch
Профиль: `{profile}`, режим: `{mode}`, стек: `{stack}`, старт: `{start_stage}`. Верно?

## error_research_required
Стадия `{stage}` требует `Research.md`. Запустите Research или используйте `--skip-research`.

## error_redo_no_artifact
Нечего переделывать — артефакта `{stage}` нет. Используйте `run --from {stage}`.

## stage_done_prompt
`{stage}` готова. Перейти к следующей? [Yes / Edit / No]
