---
name: workflow-epic
description: |
  EPIC profile workflow: Research → Plan → Execute (decomposition or pure-research) → Done. Activated by swift-toolkit:orchestrator; not invoked by the user directly.
  Use when (en): orchestrator dispatches a task with [TASK_TYPE]=EPIC
  Use when (ru): оркестратор диспетчеризует задачу с [TASK_TYPE]=EPIC
stack_axes_envelope: { may: [], never: all }
---

# Workflow Epic

This skill is **Method B** for the EPIC profile: it runs the stages when the host has no Workflow tool. `workflows/profile-epic.js` is Method A and runs the same stages as code. The orchestrator picks between them (see `swift-toolkit:orchestrator` → **Dispatch**), and `scripts/lint-workflows.sh` fails if the two stage lists drift apart. Edit a stage here and the script needs the same edit.

The profile workflow for tasks with `[TASK_TYPE] = EPIC`. Unlike the other workflow-* skills, EPIC has a branch on the Plan stage: **decomposition** (split into `.step/` subfolders and run them sequentially) or **pure_research** (Research.md is the final artifact; no implementation follows). The skill receives an already-resolved contract from the orchestrator and does not try to re-resolve any parameter on its own.

**Relationship to RESEARCH profile.** `pure_research` here is a *downgrade path*: a task started as an EPIC, the Research stage discovered no decomposition / implementation is needed. For tasks known up-front to be investigation-only (audits, feasibility studies), use `[TASK_TYPE] = RESEARCH` and the `swift-toolkit:workflow-research` profile directly — it has a simpler shape (`Research → [Review] → Done`), no decomposition logic, and an explicit single-agent choice. See `conventions/research-vs-epic.md`.

## Language Resolution

Before producing any user-facing string:

1. Read `CLAUDE-swift-toolkit.md` from the project root.
2. Find the `## Language` section.
3. Take the first non-empty line in that section, lowercase and trim it. That is `<lang>`.
4. If `<lang>` is `en` or `ru`, use it. Otherwise default to `en`.
5. Read this skill's `locales/<lang>.md`. Look up keys by H2 header.
6. If a key is missing, fall back to the same key in `locales/en.md`. If still missing, that's a bug — fail loudly with key name.

Caching: resolve `<lang>` once per skill invocation; do not re-read CLAUDE-swift-toolkit.md per string.

## 1. Input Contract

The skill is invoked by `swift-toolkit:orchestrator` via the `Skill` tool with structured `args` in `key=value` form, separated only by newlines.

The field structure is documented in `swift-toolkit:orchestrator` (section **Outbound Contract**). Workflow-epic accepts every field already filled — invariant.

If a required field arrives empty — workflow-epic does not try to recover. It returns `{status: error, reason: status_error_empty_required_field}` (the `reason` value is taken from the locale key in `locales/<lang>.md`) back to the orchestrator.

Key fields and their EPIC-specific semantics:
- `task_dir` — the resolved epic folder; every artifact this profile writes lands there, and each step folder is `<task_dir>/<step_id>`.
- `start_stage`, `end_stage`, `stage_scope` — determine which stages run.
- `start_phase` — for EPIC means the **`step_id`** (e.g. `start_phase=2.step` or `start_phase=composition-model.step`), not a phase inside a stage. Research/Plan stages are not decomposed into the usual phases — the resume unit inside Execute is a step.
- `stage_scope=single` — for EPIC means **"a single step"**, not a single stage. Used for `redo` or pinpoint re-runs of one step.
- `mode` — `manual` / `auto` (see sections 3 and 4). The epic's mode is inherited by each step at delegation time, unless the step has its own `[WORKFLOW_MODE]` in its `Task.md`.
- `stack` — passed to Research/Plan subagents, and inherited by the steps (unless they have their own `## 4. [Stack]`).
- `lang` — project language for artifact prose + the final report; artifact structure (headings, field labels, status enums) stays EN. See `conventions/i18n.md` → "Artifact authoring rule". Passed through to Research/Plan subagents and inherited by every step workflow-*.
- `need_test`, `need_review` — at the epic level only gate Plan/Research; at the step level the decision is made by each step's own workflow-* based on its own Task.md.
- `archive_paths` — paths to backups already created (the orchestrator made them BEFORE the call; workflow-epic does not create them).
- `epic_dispatch_mode` — **an additional optional field, EPIC-specific**: `push` (default) or `pull`. Forces the Execute dispatch model; omitted, the profile decides (see section 2, Execute).
- `plugin_root` — **EPIC-specific, Method A only**: the expanded absolute path of the plugin root. Method A pushes a step by launching its profile script, and the workflow sandbox cannot expand `${CLAUDE_PLUGIN_ROOT}` itself. Absent, push degrades to pull. Method B ignores it.

**Execution range.** Stages run in the order Research → Plan → Execute → Done, starting at `start_stage` and continuing through `end_stage` inclusive. If the Plan stage chose the **pure_research** branch — Execute is skipped, the workflow goes straight to Done with `branch=pure_research`. If `end_stage=null` — through the end of the profile. If `end_stage` is set but precedes `start_stage` in order, that is a contract error: return `{status: error, reason: "end_stage before start_stage"}`.

**Scope.** `stage_scope` controls execution width:
- `single` — only `start_stage` runs. For Execute that means "a single step" (the one named in `start_phase=<step_id>`).
- `forward` — `start_stage` plus every subsequent stage up to `end_stage` (or to the end of the profile).
- `all` — equivalent to `forward` with `start_stage = Research`. Used for `action=restart-full`.

## 2. Stages

A stage that names an agent is executed by that agent. Dispatch it per `conventions/stage-dispatch.md` — stage work does not run in the main context, and a stage that skips its agent says so before it starts.

- **Research** — `swift-toolkit:swift-architect`. Artifact: `Research.md` in the epic's folder. Goal: a wide investigation of the topic (context, actors, constraints, technology options, related modules). The Research output must answer: **is decomposition required** (a large initiative needs to be split into executable chunks) **or is pure research enough** (Research.md is itself the final artifact; no implementation will follow).

  For the **decomposition** branch, the architect MUST apply `feature-requirements` (epic-level Primary / Secondary / Designer / Backend / Known Unknowns) and `feature-landscape` (epic-level entity graph + layer map + integration points). `Research.md` gets `## Requirements` and `## Landscape` sections. The landscape's work-items list seeds the step decomposition in the next stage.

  For the **pure_research** branch, these sections are optional but recommended where applicable (e.g. a pure-research task investigating a feasibility question still benefits from a Requirements section to scope the inquiry).

- **Plan** — `swift-toolkit:swift-architect`. **Two branches:**

  **Branch A — Decomposition.**
  - Artifact: `Plan.md` with a progress table of **`.step/` subfolders** (not phases inside a single profile).
  - The step decomposition is seeded from `Research.md ## Landscape ### Work items`. Steps group related work items along layer or feature boundaries — typically one step per major layer (Domain / Repository / Networking / UI) or per self-contained sub-feature.
  - The architect MUST apply `feature-estimation` at the epic level and write an aggregate `## Estimation` into the epic's `Plan.md`. The epic estimate is the **sum of the per-step ranges** (each step gets its own baseline + scope-aware deltas, exactly like a cross-platform estimate sums per-platform totals — see `feature-estimation` Step 3), reported as a named best/worst epic range. Per-step ranges live in each `<step>/Plan.md ## Estimation` (written by the step's own inner workflow at its Plan stage); the epic `Plan.md ## Estimation` rolls them up and is refreshed if a step is re-scoped. Unlike a single FEATURE, the epic estimate is **not** an Execute gate — it is informational planning roll-up — but it MUST be present before the first step runs. When the project is AI-assisted, the aggregate carries both the human and the AI-assisted epic range.
  - Each step is described as a separate task: it has its own `[TASK_TYPE]` (FEATURE/BUG/REFACTOR/TEST/EPIC/RESEARCH — yes, recursive EPIC and RESEARCH are allowed), its own `[STATUS]` ∈ {TODO, ACTIVE, DONE, DEFERRED, BLOCKED, SKIPPED}, an optional `[WORKFLOW_MODE]`, and its own `## 4. [Stack]` (or inherits from the epic).
  - Step folders are created physically: `Tasks/<STATUS>/<epic-id>-<slug>/1.step/`, `2.step/`, …, `composition-model.step/` (any name with the `.step` suffix). Each contains its own `Task.md`. Creating the physical folders is the responsibility of `swift-toolkit:task-new` (see section 6).
  - The progress table in Plan.md lists steps in execution order with columns: `Done? | step_id | TASK_TYPE | [STATUS] | short description | artifact`. The **`Done?` column renders as a markdown checkbox** `- [ ]` / `- [x]` mirroring the step's `[STATUS]`: `[x]` when `[STATUS]=DONE`, `[ ]` otherwise. Workflow-epic ticks the checkbox at the moment a step's inner workflow completes (i.e. when `task-move` relocates the step to `DONE/`).

  **Branch B — Pure research.**
  - Artifact: `Research.md` is extended/finalized. `Plan.md` is optional, written as a "research roadmap" (what else needs investigation, no decomposition into executable steps).
  - The workflow proceeds straight to Done (the Execute stage is skipped; in the output contract `branch=pure_research`, `completed_steps=[]`).

  The branch decision is made based on `Research.md` and recorded inside it under an H2 heading. **CRITICAL — DO NOT TRANSLATE THE HEADING.** The heading is the byte-for-byte literal `## Decomposition decision`, written exactly that way regardless of the active language. Do not translate, localize, or adapt it — workflow-epic later parses this exact string to know which branch to take; translating it silently breaks the EPIC profile. The free-form prose under the heading IS composed by the architect agent in the user's natural language. Workflow-epic reads this section and acts accordingly — **it does not pick the branch on its own** (see section 6).

- **Execute** (only on branch A — Decomposition). Walks the `.step/` subfolders sequentially — by prefix order (`1.step` → `2.step` → … for numeric prefixes; for named ones — in the order locked in `Plan.md`). **Steps are NOT run in parallel** — strictly sequential, for predictability and clean state recovery.

  **Per-step commits.** Workflow-epic itself does NOT create commits at the epic level. Each step's inner workflow-* (refactor/feature/bug/test) is responsible for its own per-phase commits, autonomously, without a user prompt. Workflow-epic only ensures the inner workflow runs to completion; the commit history is built up step by step by the inner workflows.

  For each step:
  - Read `<step>/Task.md`, extract `[STATUS]` and `[TASK_TYPE]`.
  - If `[STATUS]` ∈ {DEFERRED, BLOCKED, SKIPPED, DONE} — skip; record the skip in the output contract's `skipped_steps` with the reason and move on.
  - Otherwise — delegate the step (see push vs pull below).
  - If the step returned `status=error` — stop the walk, record in `failed_steps`, return control to the orchestrator with status `partial` (if at least one step had already finished) or `error` (if the very first executable step failed).
  - If the step returned `status=cancelled` (user declined in its AUQ) — stop the walk, status `partial` or `cancelled`.

  **Push vs Pull dispatch models.**

  - **Push (the recommended default):** the epic runs the step itself and awaits its result before moving on. Method B invokes the `Skill` tool with `name=swift-toolkit:orchestrator` and args describing the step (effectively as a new task: `task_id=<step_id>`, the epic context inherited via args). Method A launches the step's own profile script as a nested workflow run, building its path from `plugin_root`. Either way the outcome is recorded and the walk moves on.

  - **Pull (fallback):** workflow-epic **does NOT run the step**. Instead it walks every `.step/` folder, builds an ordered list of `[{step_id, task_id, profile, mode, …}]`, and returns it to the orchestrator via the `Output Contract` in the `pending_steps` field. The orchestrator then sequentially dispatches each step itself as ordinary tasks.

  **Three things force pull, whatever `epic_dispatch_mode` says.** `manual` mode, because the orchestrator asks the user between steps and a running workflow cannot ask. A missing `plugin_root` under Method A, because the step script's path cannot be built. And a step whose own `[TASK_TYPE]` is `EPIC` under Method A, because the runtime allows exactly one level of nested workflow and a nested epic would need a second. In each case the epic stops at the step it cannot run and returns that step **and every step after it** as `pending_steps` — the walk is ordered, so resuming past a gap would run a step against a state that never existed.

  **Mode selection:**
  - If `epic_dispatch_mode=push` was passed in args — use push.
  - If `epic_dispatch_mode=pull` — use pull (skip actually running the steps; populate `pending_steps`).
  - If the field is absent — default to `push`, subject to the three forced-pull conditions above.

  The documented happy path is push. Pull is the fallback, and in `manual` mode it is the only model.

- **Done** — final report `Done.md` for the epic:
  - Which steps finished (with links to their `Done.md`).
  - Which were skipped and why (DEFERRED/BLOCKED/SKIPPED/DONE_already).
  - Which BLOCKED steps require user action (an explicit list with the blocker description).
  - Overall epic progress (X out of Y steps complete).
  - A mandatory `## Estimate retrospective` section (branch A only) that rolls up every completed step's own retrospective: the aggregate estimated epic range vs the summed actual effort, an in-range verdict, and any variance reason. Actual effort is captured per the hybrid model defined in `feature-estimation` (`## Estimate retrospective` — user-provided human effort when available, else the auto git proxy labelled as such, else `unknown`); the epic row sums the step rows in matching units and never mixes human-days with proxy values in the same total. This roll-up also appends/refreshes the epic's data point in the calibration log (`feature-estimation` Calibration over time).
  - Objections (aggregated from each step's `Done.md` if the user insisted on a contested decision in any of them).
  - For branch B (pure_research) — Done.md is short, points at `Research.md` as the final artifact; the steps section is empty; no estimate retrospective is required.

  On branch A, and only for a walk with no failed, cancelled or pending steps, also apply `swift-toolkit:task-walkthrough` and write `Walkthrough.md` — governed by `[WALKTHROUGH]` in `Task.md`, else `## Reporting` → `walkthrough` in `CLAUDE-swift-toolkit.md`, else `on`. An epic has no commits of its own: the file sits a layer above the steps, linking to each step's own walkthrough rather than restating it. Branch B gets none — there is no implementation to walk through.

## 3. Manual mode

After each stage (Research, Plan) and **after each step in Execute**, the orchestrator asks the user via the structured question mechanism using the `stage_done_prompt` key from `locales/<lang>.md`, with placeholders `{stage}` and `{step_id}`.

Workflow-epic **does NOT ask the user itself** — it returns control to the orchestrator after a stage or a step completes with `next_recommended_action`. The decision to pause, continue, or capture discussions in the epic's `Questions.md` is the orchestrator's responsibility.

In push mode, pauses between the inner stages of a step are the responsibility of the nested orchestrator call (it dispatches the step as an ordinary task). Workflow-epic only pauses between **steps themselves**, not inside them.

## 4. Auto mode

No pauses. Steps in Execute run sequentially one after another; the only interruption is when a step returns `status=error` or `status=cancelled`. Per-step commits are created autonomously by each step's inner workflow-* (no user prompt). The only commit that always requires confirmation regardless of mode is a flow-level wrap commit (squash, merge, push) the orchestrator may initiate after Done — that confirmation is the orchestrator's responsibility, not workflow-epic's.

## 5. Output Contract (extended)

The EPIC output contract is extended with fields for steps and the branch. After each stage (in `manual` mode) or after a full pass (in `auto` mode), workflow-epic returns a JSON-like structure to the orchestrator:

```
{
  status: ok | error | cancelled | interrupted | partial,
  last_completed_stage: Research | Plan | Execute | Done,
  branch: decomposition | pure_research,
  artifact_path: <path to Done.md or Research.md>,
  next_recommended_action: continue | stop | ask_user,
  notes: <free-form text, optional>,

  # For the decomposition branch — extended fields:
  completed_steps: [{step_id, task_id, status: ok|error|cancelled|interrupted}],
  skipped_steps:   [{step_id, task_id, reason: DEFERRED|BLOCKED|SKIPPED|DONE_already}],
  failed_steps:    [{step_id, task_id, error_reason}],

  # For the pull model:
  pending_steps:   [{step_id, task_id, profile, mode, stack, ...}]
}
```

Field semantics:
- `status=ok` — every executable step (or the single stage) finished successfully.
- `status=error` — a fatal error (e.g. the first step crashed or the contract was violated).
- `status=cancelled` — the user explicitly declined to continue (rendered to the user via locale key `status_cancelled_user_no`). A normal outcome.
- `status=interrupted` — execution was interrupted by a technical fault (timeout, subagent loss).
- `status=partial` — **EPIC-specific**: some steps finished successfully and some failed/blocked/cancelled. The orchestrator decides what to show the user and whether to continue.
- `branch=decomposition` — the Plan stage chose decomposition; there are steps.
- `branch=pure_research` — the Plan stage chose pure research; `completed_steps`/`skipped_steps`/`failed_steps`/`pending_steps` are empty.
- `last_completed_stage` — the last stage that actually finished. On the pure_research branch that is still `Done`: Execute is skipped, but a short `Done.md` is written, and `branch=pure_research` is what tells the orchestrator no steps ran.
- `artifact_path` — path to the key artifact: `Done.md` for decomposition; `Research.md` (or `Plan.md` if a research roadmap exists) for pure_research — a pure-research epic's deliverable is the research, not the report about it.
- `next_recommended_action=continue` — the next stage or step may start immediately; `stop` — finish or fatal error; `ask_user` — confirmation is needed (e.g. after `partial` or after a step whose Review returned `CHANGES_REQUESTED`).
- `pending_steps` — populated only in the pull model; an ordered list of steps the orchestrator must sequentially dispatch itself. In push mode this is always `[]`.

Based on this, the orchestrator decides: continue, abort, ask the user, or dispatch the pending_steps.

## 6. What workflow-epic does NOT do

- Does NOT route — profile selection happens in the orchestrator before the call.
- Does NOT read the epic's `Task.md` to determine stack/mode — everything arrives in `args`.
- Does NOT create `.step/` subfolders itself — that is the responsibility of `swift-toolkit:task-new` (invoked by the orchestrator or the user before EPIC starts, or by the Plan stage instructing the architect to create step folders via task-new).
- Does NOT modify step `[STATUS]` values — that is the job of `swift-toolkit:task-move` (invoked by the subagent inside each step at completion).
- Does NOT decide between pure_research vs decomposition — that decision is recorded inside `Research.md` under the `## Decomposition decision` heading during the Research stage; workflow-epic just reads it and acts.
- Does NOT dispatch steps in parallel — only sequentially (for predictability and clean resume).
- Does NOT create backups in `_archive/` — the orchestrator did so before handing off control; the paths are already in `archive_paths`.
- Does NOT ask the user — the orchestrator does that between stages and between steps in `manual` mode.
- Does NOT create commits at the epic level — per-phase commits are the responsibility of each step's inner workflow-* (created autonomously without a user prompt). The orchestrator handles user-facing commit confirmation only for any flow-level wrap commit it initiates after Done (squash, merge, push). **"Does NOT confirm with user" means "does not interrupt to ask"; the inner step workflows still commit per phase.**
