---
name: task-new
description: |
  Creates and fills a Task.md scaffold in Tasks/<STATUS>/NNN-slug/ (or nested as .step inside an epic). Formalizes the user's description and fills sections; does not implement anything or research the codebase.
  Use when (en): "create task", "new task", "ft", "create sub-task for N", "step for N", "named step for N"
  Use when (ru): "создай задачу", "новая задача", "ft", "создай под-задачу для N", "step для N", "шаг для N", "создай шаг <name> для N"
---

# Task New

Creates a numbered task folder + Task.md scaffold and fills it with the user's formalized description. Single action (no separate scaffold vs fill stages).

## Language Resolution

Before producing any user-facing string:

1. Read `CLAUDE.md` from the project root.
2. Find the `## Language` section.
3. Take the first non-empty line in that section, lowercase and trim it. That is `<lang>`.
4. If `<lang>` is `en` or `ru`, use it. Otherwise default to `en`.
5. Read this skill's `locales/<lang>.md`. Look up keys by H2 header.
6. If a key is missing, fall back to the same key in `locales/en.md`. If still missing, that's a bug — fail loudly with key name.

Caching: resolve `<lang>` once per skill invocation; do not re-read CLAUDE.md per string.

## Triggers

Bilingual triggers are listed in the frontmatter `description:`. Both EN and RU phrases activate the skill regardless of the project's active language; the body of the formalized Task.md follows the user's natural language.

Root task triggers cover variants like: "create task", "new task", "ft" + description, or with an explicit status ("create task in TODO", "in BACKLOG", "in RESEARCH").

Step-task triggers cover sub-tasks of an epic: "create sub-task for 137", "step for 137", "shag for epic 137" — including named steps ("create step composition-model for 137").

## Task.md Template

The template is fixed English structure (stable structural anchors). Section headings, the `**Date:**` label, and bracketed metadata (`[TASK_TYPE]`, `[NEED_TEST]`, `[NEED_REVIEW]`, `[WORKFLOW_MODE]`, `[STATUS]`) are written **literally in English** to the Task.md file regardless of the project's active language — they are parsed by other skills (orchestrator, task-status) and must stay stable. Only the prose **content** the user fills in inside those sections follows the user's language.

```markdown
**Date:** YYYY-MM-DD
# NNN-slug

[TASK_TYPE] = [FEATURE]       # FEATURE | BUG | REFACTOR | REVIEW | TEST | EPIC
[NEED_TEST] = [true]
[NEED_REVIEW] = [true]

# Step tasks only (inside an epic):
[STATUS] = [PENDING]          # PENDING | IN_PROGRESS | DONE | DEFERRED | BLOCKED | SKIPPED

# Optional (only if overriding project default from CLAUDE.md):
# [WORKFLOW_MODE] = [auto]    # manual | auto

## 1. [Files]

## 2. [Description]

## 3. [Task]

## 4. [Stack]

## 5. [Logs]

## 6. [StackTrace]
```

## Process — root task

1. **Choose the start status** by keywords (default `ACTIVE/`); the same intent in any language maps to the same status:
   - "plan it" / "in TODO" / "later" → `TODO/`
   - "to backlog" / "future idea" → `BACKLOG/`
   - "research epic" / "long research" → `RESEARCH/`
   - "in UNABLE_FIX" (rare; usually set later) → `UNABLE_FIX/`
   - Default → `ACTIVE/`
   - Explicit "create in <STATUS>" → that STATUS folder
2. **Get the next NNN**: scan every folder under `Tasks/**/` matching `^\d{3}-`, find the max, increment by 1.
3. **Make the folder**: `Tasks/<STATUS>/NNN-slug/`.
4. **Create Task.md** with the template above.
5. **Formalize the user's input** (no codebase research) and fill sections:
   - File paths, screenshot paths → `## 1. [Files]`
   - Context / current behavior / problem → `## 2. [Description]`
   - What to do / questions / reproduction steps → `## 3. [Task]`
   - Logs → `## 5. [Logs]` (only if present in the request)
   - Stack traces / crashlogs → `## 6. [StackTrace]` (only if present)
6. **Set `[TASK_TYPE]`** by intent (matched across languages):
   - "bug" / "crash" / "doesn't work" / "regression" → `BUG`
   - "epic" / "roadmap" / "investigate a large area" → `EPIC`
   - "refactor" / "extract" / "split into modules" → `REFACTOR`
   - "review" / "look at the diff" → `REVIEW`
   - "write tests" / "cover with tests" / "unit tests" → `TEST`
   - Default → `FEATURE`
7. **Flags `[NEED_TEST]` / `[NEED_REVIEW]`** — default `true`/`true`. Flip to `false` when:
   - Visual/cosmetic ("change color", "move button", "update icon", "update localization string") → `NEED_TEST = false`.
   - `TASK_TYPE` is `REVIEW`, `TEST`, or `EPIC` → both flags become `false` (not applicable).
   - The user explicitly asked for the work without tests or without review.
8. **`[WORKFLOW_MODE]`** — add ONLY if the user explicitly asked for a mode different from the project's `## Mode`. Otherwise omit.
9. **Report** the created folder path to the user. Do not start the workflow.

## Process — step task (sub-task of an epic)

1. **Identify the parent** — by number ("for 137"), slug ("for cross-platform-roadmap"), or current conversation context. Ambiguous → ask the user via `AskUserQuestion` using key `ambiguous_parent_question` with placeholder `{candidates}` (the matching folder names).
2. **Find the parent folder**: `Tasks/**/137-*` (any STATUS).
3. **Choose the step name**:
   - Numeric: find the max existing `N.step` in the parent (including sibling steps in nested epics), increment by 1 → `<N+1>.step`.
   - Named: the user said "step composition-model" → `composition-model.step`.
4. **Create** `parent/<name>.step/Task.md` using the same template, but `[STATUS]` is always included (default `PENDING`). Step tasks do NOT have their own STATUS-subfolder — they inherit their parent's folder.
5. Formalize and fill exactly like a root task.
6. Report the created path.

## Rules

- Do NOT research the codebase (no file reads, no grep, no glob beyond folder discovery).
- Do NOT add information that isn't in the user's request.
- Do NOT propose architecture or a plan — that is the job of later workflow stages.
- Sections Logs / StackTrace / Stack are created only if the user's request contains that data.
- For steps, `[STATUS] = [PENDING]` by default; any other starting status requires an explicit user statement.
- The language of the formalized prose follows the user's natural language (Russian in → Russian out; English in → English out). Structural anchors (section headings, `**Date:**`, bracketed metadata) stay English regardless.
