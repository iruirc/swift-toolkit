---
name: task-walkthrough
description: "Use at the end of an implementing stage (Execute / Fix / Refactor / Write), and again at Done, to write or refresh `Walkthrough.md` — the human-facing account of what a task actually landed: summary, plan-vs-outcome divergences with their trigger, a commit-by-commit log, mermaid diagrams where prose is worse than a picture, and follow-ups. Governed by `[WALKTHROUGH]` in Task.md and `## Reporting` in CLAUDE-swift-toolkit.md."
---

# Task Walkthrough

`Walkthrough.md` is what a person reads to learn what a task did. It is not the closing report — that is `Done.md`, which exists for the toolkit's own bookkeeping: the estimate retrospective that feeds calibration, the objections, the review loop's `## Awaiting changes` anchor. This artifact has a different reader and a longer life; it is what becomes a PR description, a changelog entry, or a handover to someone who was not there.

It is written at the **end of the implementing stage** — before anything has been validated or reviewed — because that is when "what did you build?" is actually asked. It also survives the bad path: a `FAILED` validation stops the run before `Done`, and then this file is the only account of the work that exists.

Commit messages do not make this artifact redundant. `conventions/commit-messages.md` deliberately strips them of exactly what a reader needs: the body carries WHY and not WHAT ("the diff shows WHAT"), and provenance — task, phase, ticket — is banned outright.

> **Related skills:**
> - `feature-landscape` — the design-time picture of the same feature; this is the after-the-fact one
> - `feature-estimation` — `Done.md ## Estimate retrospective` accounts for effort; this accounts for substance
> - `mobile-ops-checklist` — verification evidence with proof; this is narrative

## When to use

- End of the implementing stage: `Execute` (FEATURE), `Fix` (BUG), `Refactor` (REFACTOR), `Write` (TEST)
- Again at `Done`, but only when that stage did not run in the same invocation — a run that reached Done through a passing Validation and Review has added no commits since, one that entered at Review or Done has
- At `Done` only, for EPIC — see **EPIC**
- Not for RESEARCH or REVIEW — see **Not applicable**

## The switch

`[WALKTHROUGH] = [on|off]` in `Task.md` → `## Reporting` → `walkthrough:` in `CLAUDE-swift-toolkit.md` → `on`. First hit wins; a missing section is not an error, it is the default.

## Inputs

- `Plan.md` — the intent: the phase table and the per-phase checkboxes
- The task's own git commits — the fact: `git log` for the range, `git show` for what each one carries
- `Task.md` `## 2. [Description]` and `## 3. [Task]` — what was asked for
- The file's own previous content, when it already exists

## Coverage anchor

Second line of the file, byte-for-byte:

```
[COVERS] = <first-sha>..<last-sha>
```

Short shas of the task's own commits. This is what makes a refresh decidable without reading the whole file: the range already ends at the task's last commit → change nothing and say so; it is behind → refresh.

## Structure

Header line points at the sibling artifacts (`Done.md`, `Validation.md`, `Review.md`) instead of restating them. The build verdict has one home and this is not it.

| Section | Content | Budget |
|---|---|---|
| `## Summary` | The problem, the shape of the solution, the observable result — for someone who never opened `Plan.md` | ≤ 8 lines |
| `## Plan vs. outcome` | One row per divergence: what the plan said, what landed, why, and the trigger. Nothing diverged → the single line `Landed as planned.` | 1 row per divergence |
| `## Commits` | One block per commit, in order | 1–3 sentences each |
| `## How it works` | Diagrams, and only the prose that connects them | ≤ 2 diagrams |
| `## Follow-ups` | Deliberately deferred work, each pointing at the task that carries it, or `none` | ≤ 5 bullets |

The budgets are the spec, not a suggestion. A two-commit fix gets a dozen lines; without a stated ceiling this artifact grows into an essay nobody reads, which is the same as not writing it.

### `## Plan vs. outcome`

Each row names its **trigger**: `implementation` (reality differed once the code was open), `Validation` (a check forced the change), `Review` (a finding forced it). This is the section the artifact exists for — the plan is intent, the commits are fact, and nothing else in the task folder reconciles the two.

```markdown
| Planned | Landed | Why | Trigger |
|---|---|---|---|
| One `CartRepository` | Split into `CartReader` / `CartWriter` | The write path needed its own actor isolation | implementation |
| Optimistic delete | Delete waits for the server ack | Rollback raced the list diff | Review |
```

### `## Commits`

Per commit: short sha, subject, then what it does, which files carry it, and what it unlocks for the next one. Not a re-reading of the diff — the reason the commit exists.

```markdown
- `a1b2c3d` `feat(domain): add CartReader` — introduces the read side as a protocol over the existing
  store, so the UI can move off `CartService` before the write side is touched. `Sources/Domain/Cart*`.
```

### `## How it works`

A diagram only where prose is genuinely worse than a picture. One file changed does not earn one.

| Shape | Diagram |
|---|---|
| Components / layers and their dependencies | `graph TD` |
| A flow crossing several objects | `sequenceDiagram` |
| A state machine, a lifecycle | `stateDiagram-v2` |
| Schema or migration shape | `erDiagram` |

## Refreshing

The file is living, not append-once. On a stage that runs it when the file already exists:

1. Read `[COVERS]`. Its end already at the task's last commit → change nothing, report that.
2. Otherwise refresh, and treat the sections differently:
   - `## Commits` — **append only**. It is a log; a rework commit arrives with its own reason (`addresses Review finding 2`) and does not overwrite its predecessors.
   - `## Plan vs. outcome` — **accumulates**, each new row carrying its trigger. A round of fixes after Review is precisely the divergence worth keeping.
   - `## Summary`, `## How it works`, `## Follow-ups` — **rewritten** to the current state. The reader needs what is true now, not archaeology.
3. Update `[COVERS]`.

## Not applicable

- **REVIEW** — the profile is `['Review']`; there is no implementing stage and no Done stage to write from, and the task produces no commits of its own.
- **RESEARCH** — its commits are commits of its own artifacts, and the account of what was done is `Research.md` itself. A walkthrough would be a copy.
- **EPIC on the `pure_research` branch** — same reason: no steps ran, no implementation followed.

In these three, `[WALKTHROUGH]` set by hand is reported once and not executed, never silently dropped.

## EPIC

An epic makes no commits of its own; its steps do, each writing its own `Walkthrough.md`. It is written at `Done` rather than at the end of Execute: the epic has no Validation or Review to precede, and a walk that stopped on a failed, cancelled or pending step has no delivery to describe yet. The epic-level file sits a layer above: how the steps compose into one delivery, in what order and why, what changed in the intent along the way — linking to the steps' walkthroughs rather than restating them.

## Language

Prose in the project's language, structure in English — headings, the `[COVERS]` anchor, the trigger values. `conventions/i18n.md`, Artifact authoring rule.

## Anti-patterns to avoid

- **Restating the diff.** The diff is readable and does not rot; prose about it does. Write the reason, not the change.
- **Feeding it to the Review stage.** `swift-reviewer` exists to read the diff independently; the author's narrative anchors it. `OpsChecklist.md` is fine as its input — that is evidence, not story. The reader of this file is a person.
- **Copying the validation verdict in.** It lives in `Validation.md` and `Done.md`. Link, do not duplicate.
- **A diagram per commit.** Two diagrams is the ceiling and most tasks want zero or one.
- **Rewriting `## Commits` on refresh.** That erases the rework, which is the part worth having.

## What this skill does NOT do

- Does NOT judge the work — that is `swift-reviewer`, and the verdict is `Review.md`.
- Does NOT account for effort — that is `Done.md ## Estimate retrospective` via `feature-estimation`.
- Does NOT replace `Done.md`. The two are written by the same agent at Done and answer different questions.
- Does NOT participate in State Detection. Its presence or absence never moves a `start_stage`.
