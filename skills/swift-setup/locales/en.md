# swift-setup — en

## error_not_swift_project
Not a Swift project (no `.xcodeproj`, `.xcworkspace`, or `Package.swift` found). To create a new project use `@swift-toolkit:swift-init`.

## error_template_not_found
swift-toolkit CLAUDE.md template not found. Check installation (`~/.claude/plugins/cache/` or `~/.claude/plugins/marketplaces/`).

## auq_existing_claude_md
A `CLAUDE.md` already exists in this project. What should I do?

## auq_existing_claude_md_options
Overwrite | Backup-and-overwrite | Cancel

## auq_create_tasks_structure
Create `Tasks/` structure for managing tasks? [Yes / No]

## auq_q1_ui_label
UI framework

## auq_q2_async_label
Async approach

## auq_q3_di_label
Dependency Injection

## auq_q4_arch_label
Architecture

## auq_q5_platform_label
Platform

## auq_q6_tests_label
Test framework

## auq_q7_mode_label
Workflow mode

## report_success_template
✅ swift-toolkit configured in this project.

CLAUDE.md created with stack:
  - UI: {q1}
  - Async: {q2}
  - DI: {q3}
  - Architecture: {q4}
  - Platform: {q5}
  - Tests: {q6}
  - Mode: {q7}
  - Language: {lang}

Tasks/ structure: {tasks_status}

Next steps:
  - create your first task: /task-new <description>
  - run a task: /task-run <id>
  - check status: /task-status

## tasks_status_created
created

## tasks_status_already_existed
already existed

## tasks_status_skipped
skipped

## auq_lang_label
Toolkit language for prompts

## auq_lang_options
en | ru
