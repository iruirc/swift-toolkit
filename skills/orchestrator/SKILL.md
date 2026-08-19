---
name: orchestrator
description: |
  Routes a user request to the appropriate profile workflow (FEATURE/BUG/REFACTOR/TEST/REVIEW/EPIC/RESEARCH), resolves missing parameters (profile, mode, stack, start point), and manages stages and artifact archival.
  Use when (en): "run N", "do N", "execute N", "continue N", "only <stage> for N", "up to <stage> for N", "start from <stage> for N", "redo <stage> for N", "start from phase N.N for X", "redo phase N.N for X", "start over for N", "rerun validation for N"
  Use when (ru): "запусти N", "сделай N", "выполни N", "продолжи N", "только <stage> для N", "до <stage> для N", "начни с <stage> для N", "переделай <stage> для N", "начни с фазы N.N для X", "переделай фазу N.N для X", "начни заново для N", "перезапусти валидацию для N"
---

# Orchestrator

Single entry point for routing tasks from `Tasks/<STATUS>/<task_id>-*/` into the corresponding profile workflow. The skill accepts a minimal input (only `task_id`), fills in the remaining parameters via a deterministic algorithm, and hands control to `swift-toolkit:workflow-*` via a structured contract.

The skill itself does not perform the work of stages — it only resolves parameters, validates the command, confirms with the user (in `manual` mode), and dispatches control to the profile workflow.

## Language Resolution

Before producing any user-facing string:

1. Read `CLAUDE-swift-toolkit.md` from the project root.
2. Find the `## Language` section.
3. Take the first non-empty line in that section, lowercase and trim it. That is `<lang>`.
4. If `<lang>` is `en` or `ru`, use it. Otherwise default to `en`.
5. Read this skill's `locales/<lang>.md`. Look up keys by H2 header.
6. If a key is missing, fall back to the same key in `locales/en.md`. If still missing, that's a bug — fail loudly with key name.

Caching: resolve `<lang>` once per skill invocation; do not re-read CLAUDE-swift-toolkit.md per string.

## Agent Tooling

Use `conventions/agent-tooling.md` for host-neutral interaction terms.

A user command that reaches this skill is standing authorization to dispatch the profile's stage agents for the whole task — see `conventions/stage-dispatch.md`.

In this skill, `AskUserQuestion` / `AUQ` means the structured question
mechanism. If the active host cannot provide a structured question tool, ask the
question with numbered options in a regular message and parse the user's reply.
Use the same locale key the AUQ call would have used, for example
`fallback_profile_question`.

Reply parsing: a digit, the profile name, or an unambiguous prefix (`bug`, `ref`, `test`).

## Resilient Input Contract

The minimum viable input is just `task_id`. All other fields are optional and resolved in the Resolution Algorithm.

| Field | Type | Source | Default / Error |
|---|---|---|---|
| `task_id` | string | NL/$ARGUMENTS (e.g. `026`, `137`, `001-foo`) | **required** — error using key `error_no_task_id` |
| `action` | enum: `run` / `continue` / `redo` / `restart` / `restart-full` | parsed from the command (see triggers table) | `run` for a bare "run/do/execute N", `continue` for "continue N" |
| `stage_target` | string (profile stage name) | required for `redo` / `restart`, or for `--from` / `--to` modifiers under `run` | not needed for `run` / `continue` / `restart-full` without modifiers |
| `mode_override` | enum: `manual` / `auto` | explicit "automatically" / "step-by-step" in the request | resolved from Task.md → CLAUDE-swift-toolkit.md → `manual` |
| `stack_override` | string | stack explicitly named in the request | resolved per-axis via stack-detect (see Resolution Algorithm step 4); AUQ only for unresolved needed axes |

**Invariant:** the orchestrator does NOT crash on missing optional fields. It resolves them in the Resolution Algorithm and only then hands the fully populated contract to workflow-*.

## Routing

The orchestrator does not activate on every user request — light commands bypass it. Order of checks (first match wins):

1. **Project initialization** — "create project" / "initialize" / no `.xcodeproj` and no `Package.swift` → remind about agent `swift-toolkit:swift-init` (invocation: `@swift-toolkit:swift-init` or slash command `/swift-init`). Orchestrator does not run.
2. **Task management** — "create task" / "new task" / "ft" / "create sub-task for N" → skill `task-new`. "Move task" / "to DONE" / "step N of epic M to <STATUS>" → skill `task-move`. Orchestrator does not run.
3. **Micro-edit** — "fix" / "rename" / "change" + ≤2 files with no interface changes → execute directly with a quick check via XcodeBuildMCP. Orchestrator does not run.
4. **Otherwise** — this is task work. The orchestrator runs:
   - Is there a `Task.md` for `task_id`? Yes → read `[TASK_TYPE]`, `[WORKFLOW_MODE]` (if present), `## 4. [Stack]` (if present), `[STATUS]` (for steps).
   - No → run `task-new`, then continue.
   - Determine the profile from `[TASK_TYPE]` (see Dispatch).
   - Confirmation/skip is governed in Resolution Algorithm, step 6 (single source of truth).

## State Detection

The source of truth is `Plan.md` (the progress table with checkboxes `⬜ 🔄 ✅ ⏸ 🚫 ⊘`).

Checkbox legend: `⬜` = todo (planned), `🔄` = in progress, `✅` = done, `⏸` = paused, `🚫` = blocked, `⊘` = skipped.

State Detection is **profile-aware** and **purely file-existence driven** — the orchestrator never parses inline content of `Task.md`. Per-profile mapping from filesystem markers in the task folder to a `start_stage`:

| Profile | `Plan.md` exists | `Review.md` exists | `Research.md` exists | `Reproduce.md` exists | None of the above |
|---|---|---|---|---|---|
| FEATURE | first `⬜` phase | n/a | `Plan` | n/a | `Research` |
| EPIC | first `⬜` phase | n/a | `Plan` | n/a | `Research` |
| BUG | first `⬜` phase | n/a | `Plan` | `Diagnose` | `Reproduce` |
| REFACTOR | first `⬜` phase | n/a | `Plan` | n/a | `Analyze` |
| TEST | first `⬜` phase | n/a | `Plan` | n/a | `Analyze` |
| REVIEW | n/a | n/a | n/a | n/a | `Review` (single-stage profile) |
| RESEARCH | n/a | `Done` | `Review` (if `need_review=true`) else `Done` | n/a | `Research` |

Algorithm:

1. Task folder is in `Tasks/DONE/` OR `Done.md` exists → the task is considered finished. AUQ: confirm a full restart (=`action=restart-full`), reopen (move back into `ACTIVE/`), or exit.
2. Walk the columns of the row matching the current profile **left to right**; the first match determines `start_stage`. For BUG specifically: `Plan.md` wins over `Research.md`, which wins over `Reproduce.md`.
3. `Plan.md` exists but its progress table is missing or unparseable → consider stage `Plan` complete; start at the next stage in the profile's sequence (FEATURE/EPIC: `Execute`; BUG: `Fix`; REFACTOR: `Refactor`; TEST: `Write`); for REVIEW (no next stage), ask explicitly via AUQ. RESEARCH has no Plan stage at all — this branch is unreachable for RESEARCH. Add a warning to the user.
4. **Inline-content note.** If `Task.md` carries embedded reproduce/research/analyze material but no artifact files exist in the task folder, State Detection still picks the first stage of the profile (per the rightmost column of the table). The user can override via the `confirm_dispatch` picker (Resolution Algorithm step 6) or by passing `--from <stage>`.

**Invariant:** `start_stage` produced by State Detection is always a member of the target profile's stage list. Defense-in-depth validation runs in Resolution Algorithm step 5.5 regardless.

**De-sync:**
- `Task.md` is newer than `Plan.md` → warn that the task description may have changed after planning; suggest `redo Plan`.
- Git contains commits touching task files without checkbox updates in `Plan.md` → warn about the desync; do not block, but flag it in the outbound contract.

## Resolution Algorithm

```
1. Validate & find task folder:
   • If task_id is not provided → error using key `error_no_task_id` and stop.
   • Otherwise — locate the folder Tasks/<STATUS>/<task_id>-*/ (scan Tasks/**/<task_id>-* across all STATUS folders).
   • For steps: Tasks/**/<parent_id>-*/.../<step_id>.step/
   ↓ if not found → error using key `error_task_not_found` with placeholder `{task_id}`

2. Resolve TASK_TYPE → profile
   • Read Task.md, extract the [TASK_TYPE] field
   ↓ if missing → AUQ using key `fallback_profile_question`
   ↓ profile = workflow-<TASK_TYPE.lower()>

3. Resolve mode (priority high→low):
   mode_override (NL: "automatically" / "step-by-step")
   > Task.md [WORKFLOW_MODE]
   > CLAUDE-swift-toolkit.md "## Mode"
   > "manual" (default)

4. Resolve stack (per-axis; replaces the old monolithic chain):
   4.0 if stack_override is set (stack explicitly named in the request):
          stack := stack_override
          skip to step 5            # explicit override wins, like mode_override
   4.1 envelope := workflow-<profile> frontmatter `stack_axes_envelope`
                   (absent → {may: all, never: []})
   4.2 if envelope.never == all:                       # review, epic
          stack := raw read of CLAUDE-swift-toolkit.md ## Stack  # ambient info-only
          # NO chain, NO AUQ, NO stack-detect; skip to step 5
          # 4.2 is load-bearing: stack-detect returns {} here, not the ambient text
   4.3 scope := task file scope
               (Task.md ## 1. [Files] | fallback: plan's affected paths)
   4.4 {needed, resolved, unresolved} :=
          Skill stack-detect (task_files=scope, envelope=envelope, task_id=task_id)
       # stack-detect owns path-mapping (conventions/stack-axis-mapping.md)
       # + import-scan + per-axis chain; scan runs once
   4.4a if scope is empty (## 1. [Files] absent, blank, or comment-only
        AND no fallback affected paths):
          # defer: do NOT AUQ even for partially-unresolved axes — files
          # unknown yet (early Research/Reproduce/Analyze). Asking now would
          # cache a guessed axis into ## 4. [Stack] and poison later stages.
          stack := concatenated string of `resolved` (project-config hits only)
          note `unresolved` as deferred (informational, passed to workflow-*)
          skip 4.5 and 4.6; proceed to step 5
          # re-resolved automatically on a later stage dispatch once Diagnose/
          # Plan populates [Files] or the plan's affected paths exist
   4.5 for axis in unresolved:
          AUQ using locale key `auq_axis_<axis>_question`
              options := stack-detect Axis Catalog[axis]
          resolved[axis] := user choice
       (multiple unresolved → group into one multi-question AUQ form)
   4.6 cache: upsert Task.md → ## 4. [Stack] with resolved values
              (AUQ becomes a one-time event per task)
   4.7 stack := concatenated string of resolved values "v1+v2+v3"
              (axes not in `needed` / still absent are omitted)

5. Resolve start_stage (depends on action):
   action=run, stage_target=null  → state-detection: first unfinished stage
   action=run, stage_target=X     → start at X (--from), do not touch previous stages
   action=continue                → state-detection (same as run without stage)
   action=redo, stage_target=X    → start at X, re-execute ONLY this stage
   action=restart, stage_target=X → start at X, re-execute X and all subsequent stages
   action=restart-full            → start at the profile's first stage, re-execute all

5.5. Validate start_stage against profile.stages:
   • profile_stages := ordered stage list of the target profile (canonical source: workflow-<profile> SKILL.md heading)
   • if start_stage ∈ profile_stages → continue
   • else (defense-in-depth — covers bugs in State Detection, user typos in `--from`, future code paths):
       if mode == manual:
           recommended := the stage State Detection (Section "State Detection") would have picked
           if recommended ∉ profile_stages:                                # State Detection itself was buggy
               recommended := profile_stages[0]                            # safe fallback to profile's first stage
           options := stage_picker_options(recommended, profile_stages)   ↓ see helper below
           AUQ using key `auq_stage_recovery_question`
              placeholders: `{profile}`, `{invalid_stage}`, `{profile_stages_list}`
              options: `options` (rendered with recommended-suffix on `recommended`)
           → user picks stage S → start_stage := S, continue
           → user picks Cancel → return {status: cancelled, reason: status_cancelled_user_no}
       if mode == auto:
           return {status: error, reason: error_stage_not_in_profile,
                   notes: locale `error_stage_not_in_profile` with placeholders filled}

6. Confirmation in manual mode:
   if mode == manual:
       AUQ using key `confirm_dispatch` with placeholders `{profile}`, `{mode}`, `{stack}`, `{start_stage}`
       options (in this order):
           1. locale key `confirm_dispatch_yes`     → dispatch as resolved
           2. locale key `auq_confirm_dispatch_pick_stage` → open the picker:
                  recommended := start_stage (the stage that arrived from step 5/5.5 — by construction valid)
                  options := stage_picker_options(recommended, profile_stages)
                  AUQ using key `auq_stage_override_question`  (placeholder: `{profile}`)
                  → user picks S → start_stage := S, then dispatch
                  → user picks Cancel → return {status: cancelled, reason: status_cancelled_user_no}
           3. locale key `confirm_dispatch_cancel`  → return {status: cancelled, reason: status_cancelled_user_no}
   else:
       skip confirmation, go straight to Dispatch

   Confirmation is also skipped if both key parameters (profile AND mode) are explicitly stated in the user's original command.
   "Explicitly stated" = present as literal keywords in the request text.
   Example: `run 026 as BUG automatically` — confirmation skipped (both "BUG" and "automatically" are present).
   Example: `run 026` — confirmation required (neither profile nor mode is explicit).
```

**Stack resolution (step 4) delegates to `swift-toolkit:stack-detect`.** The
orchestrator passes `{task_files, envelope, task_id}` and receives
`{needed, resolved, unresolved}`. `stack-detect` performs no AUQ and writes no
files — the orchestrator owns the per-axis AUQ (locale keys
`auq_axis_<axis>_question`, options from the stack-detect Axis Catalog), the
`Task.md → ## 4. [Stack]` cache write, and concatenated serialization. The
default path-to-axis mapping lives in `conventions/stack-axis-mapping.md`;
projects override the global `## Stack` via `CLAUDE-swift-toolkit.md → ## Modules`.
The effective precedence is task-local `## 4. [Stack]` → module override →
global `## Stack` → import scan. When
`envelope.never == all` (review/epic), the project `## Stack` is read raw and
passed as ambient informational context only — no chain, no AUQ.

**Helper: `stage_picker_options(recommended, profile_stages)`** — deterministic picker, hard cap 4 total options (structured question option-count limit, observed empirically; exceeding it causes some hosts to silently truncate).

```
N := len(profile_stages)
if N <= 3:
    options := profile_stages + [Cancel]                     # ≤ 4 options total
else:
    i := index_of(recommended) in profile_stages
    if i == 0:        neighbors := [profile_stages[1], profile_stages[2]]
    elif i == N - 1:  neighbors := [profile_stages[N-2], profile_stages[N-3]]
    else:             neighbors := [profile_stages[i-1], profile_stages[i+1]]
    options := [recommended, *neighbors, Cancel]             # exactly 4
```

Rendering rules:

- `recommended` carries the locale key `auq_stage_recovery_recommended_suffix` appended to its label. Other stages are unannotated.
- The Cancel option uses locale key `confirm_dispatch_cancel`.
- Stages are rendered **in profile order** (so neighbors render in their natural positions, not as "recommended + neighbors").
- If the user wants a stage that is not in the picker (far from `recommended`): pick Cancel and re-invoke with `--from <stage>`.

Worked examples for BUG profile (`profile_stages = [Reproduce, Diagnose, Plan, Fix, Validation, Review, Done]`, N=7):

- `recommended = Reproduce` (i=0) → picker = `[Reproduce (R), Diagnose, Plan, Cancel]`
- `recommended = Plan` (i=2) → picker = `[Diagnose, Plan (R), Fix, Cancel]`
- `recommended = Done` (i=6) → picker = `[Validation, Review, Done (R), Cancel]`

See also the "Stage Management" section — it details the semantics of `run --from` / `redo` / `restart` / `restart-full` and the "what gets archived" matrix.

## Outbound Contract

After Resolution, the orchestrator hands these fields to the dispatch path chosen in **Dispatch**. The fields are identical either way; only the encoding differs. Method B takes `key=value` form, **separated only by newlines** (a comma is NOT used as a field separator). Method A takes the same fields as a JSON object. **All fields are filled** — neither workflow-* nor a workflow script tries to recover anything.

Multi-valued fields (e.g. `archive_paths`) are encoded in **list syntax**: square brackets, commas inside.

```
task_id=001
task_dir=Tasks/ACTIVE/001-feature-search
profile=feature
action=run|continue|redo|restart|restart-full
start_stage=Plan
start_phase=2.3
end_stage=null
stage_scope=single|forward|all
mode=manual|auto
lang=ru|en
stack=swiftui+combine+swinject
need_test=true|false
need_review=true|false
archive_paths=[Tasks/ACTIVE/001-profile/_archive/Plan-2026-04-25T143022.md, Tasks/ACTIVE/001-profile/_archive/Research-2026-04-25T143022.md]
```

Semantics of `stage_scope`:
- `single` — only `start_stage` (for `redo`)
- `forward` — `start_stage` → end (for `run --from`, `continue`, `restart <stage>`)
- `all` — every stage of the profile, from first to last (for `restart-full`)

`end_stage` — filled only when `--to <stage>` is used (e.g. "do 026 up to plan"); otherwise `null`.

`start_phase` — for phase-level resume inside a stage (e.g. `Execute:phase=2.3`). Filled only when the trigger names a phase ("start from phase 2.3", "redo phase 2.3"); otherwise `null`.

`task_dir` — the resolved task folder, `Tasks/<STATUS>/<task_id>-*/`, without a trailing slash. The orchestrator already holds this path (it archives into it), and passing it explicitly is what keeps two agents from disagreeing about which folder they are working in. Required: a Method A script has no filesystem access and cannot glob for it, and refuses to start without it.

`lang` — the `<lang>` resolved by the Language Resolution section (`ru` | `en`; default `en`). Always filled. The subagent uses it for artifact **prose** and its final report; artifact **structure** stays EN regardless (see `conventions/i18n.md` → "Artifact authoring rule"). Passing it explicitly means workflow-* / subagents never re-read `CLAUDE-swift-toolkit.md` for output language.

`archive_paths` — list of paths to backups already created in `_archive/` for stages that will be overwritten (filled before handing off control). Format: `[path1, path2, path3]`. Empty list = `[]`.

**Invariant:** workflow-* never receives empty fields. If a field arrives empty — workflow-* returns an error to the orchestrator and does not try to recover.

**RESEARCH-only optional field — `research_agent`.** When `profile=research`, the orchestrator MAY include `research_agent=swift-architect|swift-diagnostics|swift-security` in the args. The field carries a BARE agent name (without the `swift-toolkit:` prefix); workflow-research resolves it to the prefixed form at dispatch time, mirroring how `[TASK_TYPE]` carries `FEATURE` rather than `swift-toolkit:workflow-feature`. Resolution:

1. If `[RESEARCH_AGENT] = <value>` is present in `Task.md` (between `[NEED_REVIEW]` and section `## 1. [Files]`) → use that value.
2. Else, scan Task.md `## 2. [Description]` and `## 3. [Task]` for keywords:
   - keywords from locale key `research_agent_diagnostics_keywords` → suggest `swift-diagnostics`
   - keywords from locale key `research_agent_security_keywords` → suggest `swift-security`
   - none / ambiguous → suggest `swift-architect`
3. In `manual` mode: AUQ using key `auq_research_agent_question`, listing the suggested agent first with the locale-key suffix `auq_stage_recovery_recommended_suffix` appended to its label — same pattern used by the stage-picker (Resolution Algorithm § 5.5 / § 6). The remaining catalog options (`swift-architect`, `swift-diagnostics`, `swift-security` minus the suggestion) follow in catalog order, plus a Cancel option using key `confirm_dispatch_cancel`. The user's pick is written back to `Task.md` under `[RESEARCH_AGENT] = [<value>]` so subsequent runs don't re-ask.
4. In `auto` mode: take the suggestion without asking.
5. For all other profiles: `research_agent` is omitted from the args (workflow-* would ignore it anyway).

**Validation.** The orchestrator does NOT validate the chosen agent name against the catalog `{swift-architect, swift-diagnostics, swift-security}` — that responsibility lies with workflow-research at dispatch entry (see `skills/workflow-research/SKILL.md` § 1, the `research_agent` bullet). An invalid value (e.g. a typo in `[RESEARCH_AGENT]`) propagates verbatim into the args; workflow-research rejects it with `{status: error, reason: <locale>}` rather than silently substituting a default.

## Dispatch

A profile has up to two executable forms. **Method A** is a workflow script the runtime executes, so the stage sequence is code rather than an instruction. **Method B** is the skill that has always run the profile. They implement the same stages — `scripts/lint-workflows.sh` fails the build if they drift — and the orchestrator picks between them once per task, not once per stage.

| TASK_TYPE | Method A — workflow script | Method B — skill |
|---|---|---|
| FEATURE | `workflows/profile-feature.js` | `swift-toolkit:workflow-feature` |
| BUG | `workflows/profile-bug.js` | `swift-toolkit:workflow-bug` |
| REFACTOR | `workflows/profile-refactor.js` | `swift-toolkit:workflow-refactor` |
| TEST | `workflows/profile-test.js` | `swift-toolkit:workflow-test` |
| REVIEW | — | `swift-toolkit:workflow-review` |
| EPIC | — | `swift-toolkit:workflow-epic` |
| RESEARCH | — | `swift-toolkit:workflow-research` |

A `—` means no script exists for that profile yet and it always takes Method B. Never construct a `scriptPath` for a profile this table does not list — a missing file fails the run after the user has already been told the task started.

**Choosing the path.** Check whether `Workflow` is among the tools you can call **right now** — the ones handed to you with their parameters. Its appearance in this table, in a skill's prose, or in an agent's `tools` line does not count: look, do not assume. Then:

- `Workflow` is callable AND the profile has a Method A script → Method A.
- anything else → Method B, exactly as before.

State the choice **once**, in the first stage report of the task, using key `dispatch_method_a` or `dispatch_method_b`. Not per stage.

**Method A — invoke.**

```
Workflow({
  scriptPath: "${CLAUDE_PLUGIN_ROOT}/workflows/profile-<profile>.js",
  args: { <the Outbound Contract, as a JSON object> }
})
```

`scriptPath` rather than `name`: the workflow registry is built at session start, so a plugin updated mid-session resolves by path but not yet by name. If `${CLAUDE_PLUGIN_ROOT}` does not expand, resolve the toolkit root the way `conventions/agent-tooling.md` describes and build the path from there.

Pass `args` as a real JSON object. A JSON-encoded string arrives at the script as a string.

**Method A — manual mode.** A running workflow cannot ask the user anything. So `manual` mode dispatches **one workflow per stage**: `stage_scope=single` with `start_stage=<stage>`, wait for the result, run the usual post-stage gating (open-questions inspection, then `stage_done_prompt`), then dispatch the next stage. `auto` mode passes the whole range in a single call.

**Method A — reading the result.** The script returns the same Output Contract every `workflow-*` skill returns — `status`, `last_completed_stage`, `artifact_path`, `next_recommended_action`, `notes` — plus the stage status fields where they apply: `validation_status`, `review_status`, `reproducible`, `blocked_phase`. Gate on those fields rather than re-reading the artifact's first line. The first line is still written and still what a human reads; it is simply no longer the parsing surface.

`status: error` with `reason: no-args` means the contract never reached the script. Do not run the stage by hand and do not slide over to Method B as if nothing happened — say what happened, then re-dispatch with the contract filled.

**Method B — invoke.** Unchanged: invoke the `Skill` tool with the name from the table and `args` in Outbound Contract format.

## Gating

**Manual** (default) — pause after each stage with an AUQ (use key `stage_done_prompt` with placeholder `{stage}`) confirming the move to the next; discussions that don't fit in a single reply are recorded in the task's `Questions.md`.

**Auto** — no pauses between stages.

**Open-questions inline (research-style stages).** In `manual` mode, before rendering `stage_done_prompt`, the orchestrator inspects the just-completed stage's primary artifact (`Research.md` for FEATURE/EPIC/RESEARCH Research; `Reproduce.md` and `Research.md` for BUG; `Analyze.md` for REFACTOR/TEST) for non-empty open-question sections.

Recognized H3 section titles (case-insensitive, scoped under any H2):
- `### Designer questions`
- `### Backend questions`
- `### Known unknowns`
- `### Open questions`

Per-item rule: a bullet (`- ` or `* `) counts as open if it does NOT start with `[RESOLVED]` or `[DEFERRED]` after the bullet marker. The orchestrator collects open items as `{section, id_or_text}` pairs (id = leading token like `D1`, `U7`, `R3` when present; otherwise first 80 chars of the item text).

If at least one open item is found → render `stage_done_prompt_with_questions` instead of `stage_done_prompt`, with placeholders `{stage}` and `{questions}` (the formatted list of open items, grouped by section). AUQ options:

1. `stage_done_option_continue` → proceed to next stage; open items propagate untouched (will hit Plan-stage estimation-gate later if blocking).
2. `stage_done_option_resolve` → enter Q-by-Q resolution dialog (see below).
3. `stage_done_option_edit` → instruct the user to edit the artifact manually; on return, re-run open-questions inspection from scratch.
4. `confirm_dispatch_cancel` → return `{status: cancelled, reason: status_cancelled_user_no}`.

If no open items found → render the unchanged `stage_done_prompt`.

**Q-by-Q resolution dialog.** For each collected open item, in source order, AUQ using `stage_done_dialog_question` (placeholders `{n}`, `{total}`, `{section}`, `{text}`) with options:
1. `stage_done_dialog_answer` → prompt the user for free-form text; append the answer as a sub-bullet under the original item and prefix the original bullet with `[RESOLVED]`.
2. `stage_done_dialog_defer` → prefix the original bullet with `[DEFERRED]`; no answer recorded.
3. `stage_done_dialog_skip` → leave item untouched.
4. `confirm_dispatch_cancel` → abort the dialog; return to the `stage_done_prompt_with_questions` AUQ with the (possibly partially) updated list.

Edits land in the primary artifact in-place; an `## Open Questions Log` section is appended to `Questions.md` (created if absent) with one bullet per resolved or deferred item, format: `- [<stage>] [<section>] <id_or_text> — <RESOLVED: answer | DEFERRED>`.

After the dialog finishes (all items processed OR user aborted), re-run the open-questions inspection on the updated artifact and re-render `stage_done_prompt_with_questions` until either zero open items remain or the user picks `stage_done_option_continue` / `confirm_dispatch_cancel`.

**Scope:** the inspection runs ONLY at stage-done boundaries that produce a research-style artifact. It does NOT run after Plan / Execute / Validation / Review / Done. The `workflow-*` Output Contract is unchanged — open-questions handling is entirely orchestrator-side and does not require new fields in `next_recommended_action`.

**Per-phase commits vs flow-level commits.** The "commit always confirmed with user" rule applies ONLY to flow-level wrap commits the orchestrator itself initiates (squash, merge, push) — these are user-confirmed regardless of mode. **Per-phase commits inside a workflow-* multi-phase stage (Refactor / Execute / Fix / Write) are autonomous** — the workflow-* skill creates one commit per green phase without a user prompt, in both manual and auto modes. The orchestrator MUST NOT misread "does not confirm commit with user" inside workflow-* skills as "does not commit at all"; per-phase commits are mandatory for the phase invariant ("each phase independently buildable+test-passing+committed") to hold against interrupts.

**Backup before overwriting / removing an artifact:** copy to `Tasks/<STATUS>/<task_id>-*/_archive/<stage>-<timestamp>.md`, where `<timestamp>` is ISO-8601 without colons (`2026-04-25T143022`). The orchestrator makes the backup BEFORE calling workflow-* and passes the paths via `archive_paths` in the outbound contract.

In `manual` mode, a structured confirmation is mandatory before the backup / removal.

## Stage Management

Triggers (free-form, parsed into `action` + `stage_target`):

| User text | action | stage_target | stage_scope |
|---|---|---|---|
| "run 026" / "do 026" / "execute 026" | `run` | null | `forward` (from the state-detection point) |
| "continue 026" | `continue` | null | `forward` |
| "do 026 up to plan" | `run` | null (`end_stage=Plan`) | `forward` (capped at the top) |
| "only plan for 026" / "only research for 026" | `run` | `<stage>` (`end_stage=<stage>`) | `single` |
| "start from Plan for 026" | `run` | `Plan` (as `--from`) | `forward` |
| "redo plan for 026" | `redo` | `Plan` | `single` |
| "start from phase 2.3 for 026" | `run` | `<stage>:phase=2.3` | `forward` (from the phase anchor) |
| "redo phase 2.3 for 026" | `redo` | `<stage>:phase=2.3` | `single` (at the phase level) |
| "rerun validation for 026" | `redo` | `Validation` | `single` |
| "start over for 026" | `restart-full` | null | `all` |

> Note on the semantics of "rerun": `rerun <stage>` = `redo` of a single stage (an atomic redo). Do not confuse it with `restart`, which resets `<stage>` AND every subsequent stage. The user verb "rerun" here is closer in meaning to "redo atomically" than to "reset and walk through to the end again".

Action and archival semantics:

| Action | Semantics | What gets archived in `_archive/` | Where it starts |
|---|---|---|---|
| `run --from <stage>` | Skip previous stages | nothing | from `<stage>` |
| `redo <stage>` | Redo one stage | `<stage>` artifact | from `<stage>`, after = untouched |
| `restart <stage>` | Reset and rerun from stage to end | `<stage>` and all subsequent | from `<stage>` to end of profile |
| `restart-full` | Full reset | all artifacts | from the profile's first stage |

**All redo / restart operations in manual mode require a structured confirmation BEFORE archiving.**

Command validation:
- "only Plan" / "start from Plan" without `Research.md` (for profiles that have a preceding `Research`) → error using key `error_research_required` with placeholder `{stage}`.
- "redo <stage>" with no `<stage>` artifact present → error using key `error_redo_no_artifact` with placeholder `{stage}`; suggest `run --from <stage>`.
- An out-of-profile stage name → handled centrally in Resolution Algorithm step 5.5 (manual: stage picker; auto: hard error using key `error_stage_not_in_profile`).

## Subagent Context

The workflow-* subagent receives:

1. The full text of the task's `Task.md` (as is).
2. A short summary of previous stages (1–3 paragraphs): what was done, key decisions, open questions. Pulled from the most recent artifacts (`Research.md`, `Plan.md`).
3. Stack: the `stack` value from the Outbound Contract.
4. Mode: `mode` from the Outbound Contract.
5. Lang: the `lang` value from the Outbound Contract (resolved once via the
   Language Resolution section). The subagent writes artifact **prose** and its
   final report in `lang`; artifact **structure** (headings, field labels,
   status enums) stays EN. See `conventions/i18n.md` → "Artifact authoring
   rule". Passing `lang` explicitly means the subagent never re-reads
   `CLAUDE-swift-toolkit.md` to decide output language.

**The stack does not need to be re-sent in full text:** the skill does not read `CLAUDE-swift-toolkit.md` — stack, mode, and paths come from the context the active agent host typically loads at session start (when `CLAUDE.md` is present at the project root and imports `CLAUDE-swift-toolkit.md` via `@./`). The orchestrator parses this already-loaded context to resolve priorities.
