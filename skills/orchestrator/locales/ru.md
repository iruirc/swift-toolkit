# orchestrator — ru

## error_no_task_id
Укажи номер задачи, например `запусти 026` / `/task-run 026`.

## error_task_not_found
Задача `{task_id}` не найдена в `Tasks/`.

## fallback_profile_question
Какой профиль? (1) FEATURE (2) BUG (3) REFACTOR (4) TEST (5) REVIEW (6) EPIC (7) RESEARCH

## confirm_dispatch
Профиль: `{profile}`, режим: `{mode}`, стек: `{stack}`, старт: `{start_stage}`. Верно?

## error_research_required
Стадия `{stage}` требует `Research.md`. Запустите Research или используйте `--skip-research`.

## error_redo_no_artifact
Нечего переделывать — артефакта `{stage}` нет. Используйте `run --from {stage}`.

## stage_done_prompt
`{stage}` готова. Перейти к следующей? [Yes / Edit / No]

## stage_done_prompt_with_questions
`{stage}` готова, но в артефакте остались открытые вопросы:

{questions}

Что делаем?

## stage_done_option_continue
Перейти к следующей стадии

## stage_done_option_resolve
Ответить на вопросы сейчас

## stage_done_option_edit
Править артефакт вручную

## stage_done_dialog_question
Вопрос {n}/{total} — `{section}`: {text}

## stage_done_dialog_answer
Ответить

## stage_done_dialog_defer
Отложить (DEFERRED)

## stage_done_dialog_skip
Пропустить (вернуться позже)

## auq_stage_recovery_question
Стадия `{invalid_stage}` не входит в профиль `{profile}`. Допустимы: {profile_stages_list}. Выберите одну:

## auq_stage_override_question
Выберите другую стартовую стадию для профиля `{profile}`:

## auq_stage_recovery_recommended_suffix
(Рекомендуется)

## auq_confirm_dispatch_pick_stage
Нет, выбрать другую стадию

## error_stage_not_in_profile
`{invalid_stage}` — недопустимая стадия профиля `{profile}`. Допустимы: {profile_stages_list}.

## confirm_dispatch_yes
Да

## confirm_dispatch_cancel
Отмена

## auq_axis_ui_question
Какой UI-фреймворк использует эта задача?

## auq_axis_async_question
Какой async-подход использует эта задача?

## auq_axis_di_question
Какой подход Dependency Injection использует эта задача?

## auq_axis_architecture_question
Какую архитектуру использует эта задача?

## auq_axis_platform_question
Какую целевую платформу использует эта задача?

## auq_axis_tests_question
Какой тестовый фреймворк использует эта задача?

## auq_research_agent_question
Какой агент должен выполнить стадию Research?

## auq_research_agent_architect
Architect — feasibility, сравнительный анализ, исследование домена

## auq_research_agent_diagnostics
Diagnostics — аудит, инвентарь, поиск паттерна

## auq_research_agent_security
Security — OWASP, уязвимость, аудит pinning

## research_agent_diagnostics_keywords
audit; inventory; grep all; аудит; найди все

## research_agent_security_keywords
security; OWASP; vulnerability; pinning; безопасность

## dispatch_method_a
Стадии профиля {profile} идут через workflow-конвейер — последовательность держит рантайм, по агенту на стадию.

## dispatch_method_b
Тул Workflow в этой сессии недоступен, поэтому профиль {profile} идёт через свой скилл. Стадии и агенты те же, но последовательность держит ассистент, а не код.

## stage_error_prompt
Стадия {stage} вернула ошибку: {reason}. Диапазон останавливается здесь — следующая стадия строила бы работу на незавершённой.

## stage_error_option_retry
Повторить {stage}

## stage_error_option_stop
Остановиться и вернуть управление

## progress_open_header
{profile} {task_id} · {method} · {start} → {end} · Progress: {progress}

## progress_open_live_hint
Живой ход идущего workflow — вьюха /workflows.

## progress_open_live_ticker_note
Панель с токенами — запусти `bash "{script}" --session {session}` в соседней панели терминала.

## progress_open_method_b_live
В Method B хост сам рисует каждый вызов агента; панель добавляет к нему цифры расхода, которых хост не показывает.

## progress_stage_report
{stage} — {agent}

## progress_stage_artifact
Артефакт: {path}

## progress_stage_verdict
Вердикт: {verdict}

## progress_stage_metrics
{model} · {out} out · {ctx} ctx · {tools} tools · {elapsed}

## progress_run_elapsed
Прогон занял {elapsed}.

## progress_run_totals
{agents} агентов · {out} out · {elapsed}

## progress_run_volume
{total} итого · {cacheRead} cache-read · {cacheWrite} cache-write · {in} in

## dispatch_blocked_prompt
Тул Workflow доступен, и у профиля {profile} есть workflow-скрипт, но запуску мешает {reason}. Method B прогонит те же стадии через скилл.

## dispatch_blocked_option_a
Запустить через workflow (Method A)

## dispatch_blocked_option_b
Запустить через скилл (Method B)
