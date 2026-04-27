---
name: swift-setup
description: |
  Configures swift-toolkit in an existing Swift project: copies CLAUDE.md from a template, fills the stack via AskUserQuestion, creates the Tasks/ structure.
  Use when (en): "set up swift-toolkit", "configure swift-toolkit", "install toolkit in project", "add swift-toolkit to project", "init toolkit here", "/swift-setup"
  Use when (ru): "настрой swift-toolkit", "подключи swift-toolkit", "установи toolkit в проект", "добавь swift-toolkit к проекту", "инициализируй toolkit здесь", "/swift-setup"
  For generating a NEW Swift project from scratch use `@swift-toolkit:swift-init`.
---

# Swift Setup

Bootstraps swift-toolkit in an **already existing** Swift project: copies the plugin's `CLAUDE.md` template into the project root, asks for the stack via `AskUserQuestion`, fills placeholders, and (optionally) creates the `Tasks/` structure.

The skill does NOT create an Xcode project, does NOT modify Swift code, and does NOT start any workflow. It is a one-time setup of the toolkit's infrastructure inside the project.

To generate a project from scratch, use the `@swift-toolkit:swift-init` agent (via the `/swift-init` slash command).

## Language Resolution

Special case for `swift-setup`: the project's `CLAUDE.md` does not yet exist (we are creating it), so there is no `## Language` to read upfront. The skill therefore asks for the language as the very first question (q0) using keys `auq_lang_label` and `auq_lang_options`. Until that answer arrives, the q0 prompt is shown bilingually (English label / Russian label) so users of either language can read it. From q0 onward, `<lang>` is the chosen value (`en` or `ru`), and every subsequent AUQ / error / report uses `locales/<lang>.md`. If for any reason q0 is skipped (text fallback, harness limitation), default to `en`.

The full resolution procedure used elsewhere — read `CLAUDE.md → ## Language` — applies after `swift-setup` has finished and written the section.

## Triggers

Bilingual triggers are listed in the frontmatter `description:`. Both EN and RU phrases activate the skill.

## Preconditions

- The current working directory is the root of an existing Swift project (it has `.xcodeproj`, `.xcworkspace`, or `Package.swift`).
- If `CLAUDE.md` already exists in the root — ask the user via `AskUserQuestion` using key `auq_existing_claude_md` with options from `auq_existing_claude_md_options`.
- If `Tasks/` already exists — do NOT overwrite; skip the create step.

## Tool Loading (preamble)

`AskUserQuestion` in the current Claude Code is loaded lazily. The **first action** the skill performs:

```
ToolSearch select:AskUserQuestion
```

Once the schema is loaded, `AskUserQuestion` may be called. If loading fails (older environment, tool missing) — use a textual fallback: numbered options in a regular message, parse the reply (digit, option name, or unambiguous prefix).

## Algorithm

```
0. Ask the language (q0):
   AskUserQuestion using key `auq_lang_label` with options from key `auq_lang_options` (`en` / `ru`).
   Store the answer as <lang>; from this point on, all user-facing prompts and reports use locales/<lang>.md.
   This step has no localization fallback (it's the first localized output) — display the question
   bilingually (the English label and the Russian label side by side) so either-language users can read it.
   If q0 is skipped (text fallback, harness limitation), default <lang> to `en`.

1. Detect project state:
   a. Check for .xcodeproj / .xcworkspace / Package.swift in the root.
      ↓ if none → render the error using key `error_not_swift_project`. Stop.
   b. Check for CLAUDE.md in the root.
      ↓ if present → AskUserQuestion using key `auq_existing_claude_md` with options
         from `auq_existing_claude_md_options` (Overwrite / Backup-and-overwrite / Cancel).
         - Overwrite: continue, overwrite.
         - Backup-and-overwrite: rename to CLAUDE.md.bak (timestamp suffix on collision), continue.
         - Cancel: stop, report.
   c. Check for Tasks/ in the root.
      ↓ if present → set tasks_exist=true, skip step 5.

2. Locate plugin CLAUDE.md template (lookup strategy, Read the first existing path) using <lang> from step 0:
   a. ~/.claude/plugins/cache/swift-toolkit/swift-toolkit/<version>/templates/claude-md/<lang>.md
      (latest version — pick the most recent directory if there are several)
   b. ~/.claude/plugins/marketplaces/swift-toolkit/templates/claude-md/<lang>.md
   c. If neither path is available → render the error using key `error_template_not_found`. Stop.

3. Stack questions (AUQ, sequentially or as one multi-form). Labels come from locale keys
   (`auq_q1_ui_label` … `auq_q7_mode_label`):
   q1. UI: SwiftUI / UIKit / AppKit
   q2. Async: async/await / Combine / RxSwift
   q3. DI: Swinject / Factory / manual
   q4. Architecture: MVVM+Coordinator / VIPER / Clean Architecture / MVC
       — if the user answers "I don't know" / "advise me" / "you choose" — run the
         `architecture-choice` skill (5-axis compass), bring its result back here as
         q4 plus a one-line justification.
   q5. Platform: iOS 17+ / iOS 16+ / macOS 14+ / macOS 13+ / iOS+macOS
   q6. Tests: XCTest / Quick+Nimble
   q7. Mode: manual (default) / auto
       — may be skipped, leaving `manual`.

4. Write CLAUDE.md to the project root:
   - Read the template body from step 2 (already in the chosen language).
   - Replace placeholders (see Placeholder Replacements).
   - Substitute the chosen mode into the `## Mode` section.
   - Write the result to <project>/CLAUDE.md.
   - The `## Language` section in the written file equals <lang>.

5. Optional Tasks/ structure:
   If tasks_exist=false:
     AUQ using key `auq_create_tasks_structure`.
     ↓ Yes →
       mkdir -p Tasks/{TODO,ACTIVE,DONE,BACKLOG,RESEARCH,CHECK,UNABLE_FIX}
       Create .gitkeep in each subfolder (so empty folders make it into git).
     ↓ No → skip.

6. Report rendered using key `report_success_template` with placeholders {q1..q7},
   {lang}, {tasks_status}; tasks_status is one of `tasks_status_created` /
   `tasks_status_already_existed` / `tasks_status_skipped`.
```

## Placeholder Replacements

| Placeholder in template                                          | Filled from |
|------------------------------------------------------------------|-------------|
| `<SwiftUI \| UIKit \| AppKit>`                                   | q1 — UI |
| `<async/await \| Combine \| RxSwift>`                            | q2 — Async |
| `<Swinject \| Factory \| manual>`                                | q3 — DI |
| `<MVVM+Coordinator \| VIPER \| Clean Architecture \| MVC>`       | q4 — Architecture |
| `<iOS 16+ \| macOS 13+ \| iOS+macOS>`                            | q5 — Platform |
| `<XCTest \| Quick+Nimble>`                                       | q6 — Tests |
| `manual` in `## Mode`                                            | q7 — Mode (or keep `manual`) |
| `en` / `ru` in `## Language`                                     | q0 — Language (set in step 4) |

Replacements are strict — only the listed placeholders. Other content (Persona, Orchestration, Modules, Paths) is copied unchanged from the localized template (`templates/claude-md/<lang>.md`).

## Output report

The report is rendered from the locale key `report_success_template` with placeholders for the chosen stack values, the language, and the `Tasks/` status. See `locales/<lang>.md` for the exact wording.

## Edge cases

- **CLAUDE.md already exists** → `AskUserQuestion` using `auq_existing_claude_md` with options from `auq_existing_claude_md_options`. Backup creates `CLAUDE.md.bak`; on collision use `CLAUDE.md.bak.YYYYMMDD-HHMMSS`.
- **Not a Swift project** (no `.xcodeproj` / `.xcworkspace` / `Package.swift`) → render the error using key `error_not_swift_project` and stop.
- **Plugin template not found** in either `cache` or `marketplaces` → render the error using key `error_template_not_found` and stop.
- **Tasks/ already exists** → do not overwrite, do not propose creation; in the report use `tasks_status_already_existed`.
- **AUQ unavailable** → text fallback with numbered options for each question; parse the reply (digit / name / prefix).
- **User cancelled the setup** (Cancel on the CLAUDE.md step) → exit without disk changes.

## What this skill does NOT do

- Does NOT create an Xcode project, `Package.swift`, sources, `.swiftlint.yml`, or `README.md` — that is the job of `@swift-toolkit:swift-init`.
- Does NOT modify Swift code and does NOT alter existing configs (Info.plist, Build Settings, etc.).
- Does NOT start workflows (`workflow-feature` etc.) and does not call `orchestrator`.
- Does NOT init git and does not make commits.
- Does NOT install dependencies (SPM, CocoaPods, Carthage).
- Does NOT create the first task — that is done separately via `/task-new`.
