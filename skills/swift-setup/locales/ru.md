# swift-setup — ru

## error_not_swift_project
Не Swift-проект (не найден `.xcodeproj`, `.xcworkspace` или `Package.swift`). Для генерации нового используй `@swift-toolkit:swift-init`.

## error_template_not_found
Шаблон CLAUDE.md плагина не найден. Проверь установку swift-toolkit (`~/.claude/plugins/cache/` или `~/.claude/plugins/marketplaces/`).

## auq_existing_claude_md
В проекте уже есть `CLAUDE.md`. Что сделать?

## auq_existing_claude_md_options
Overwrite | Backup-and-overwrite | Cancel

## auq_create_tasks_structure
Создать `Tasks/` структуру для управления задачами? [Yes / No]

## auq_q1_ui_label
UI-фреймворк

## auq_q2_async_label
Async-подход

## auq_q3_di_label
Dependency Injection

## auq_q4_arch_label
Архитектура

## auq_q5_platform_label
Платформа

## auq_q6_tests_label
Тестовый фреймворк

## auq_q7_mode_label
Режим воркфлоу

## report_success_template
✅ swift-toolkit настроен в этом проекте.

CLAUDE.md создан со стеком:
  - UI: {q1}
  - Async: {q2}
  - DI: {q3}
  - Архитектура: {q4}
  - Платформа: {q5}
  - Тесты: {q6}
  - Режим: {q7}
  - Язык: {lang}

Tasks/ структура: {tasks_status}

Следующие шаги:
  - создать первую задачу: /task-new <описание>
  - запустить задачу: /task-run <id>
  - посмотреть статус: /task-status

## tasks_status_created
создана

## tasks_status_already_existed
уже существовала

## tasks_status_skipped
пропущена

## auq_lang_label
Язык подсказок toolkit

## auq_lang_options
en | ru
