# CLAUDE-swift-toolkit.md — Swift Toolkit Configuration

> Toolkit-owned configuration for a Swift/Apple project. Created and updated by `swift-setup`.
> **Do not edit by hand unless you know what you're doing** — running `swift-setup` again may overwrite your changes (after backup).
> User-owned project instructions live in `CLAUDE.md`. This file is auto-imported into Claude's context via `@./CLAUDE-swift-toolkit.md`.
> Task-orchestration logic is in the `swift-toolkit:*` skills (see "Orchestration" below).

## Language

en

## Persona

- Communication language: <Communication Language>
- **I have the right to disagree** with the user's decisions. If a decision leads to a hack, a security hole, or technical debt — I MUST object and propose an alternative.
- **Quality and security > speed.** Do not accept "we'll fix it later", "good enough for MVP", "this is temporary".
- **Long-term value > quick wins.** Pick solutions that scale and remain maintainable.
- If the user insists on a hacky solution, clearly outline the risks and record them in `Done.md → Objections`.

## Rules

### Comments

- **Default to writing no comments.** Code with descriptive names says WHAT. Only add a comment when the WHY is non-obvious: hidden constraint, subtle invariant, workaround for a specific bug, behavior that would surprise a reader.
- **Comments must be evergreen** — encode an invariant that will still be true in two years.
- **NEVER reference the current task, phase, EPIC, ticket, fix, PR, or caller** in production code comments. Forbidden examples: `// EPIC 145 §1.6 Phase 5 — …`, `// Task 042 phase 2`, `// Bug123 fix`, `// Used by Y flow`, `// §1.7 follow-up will replace this`, `// Was X before refactor`. Provenance lives in `git log` / commit message / PR description / `Tasks/` — duplicating it in code rots and crowds out the WHY.
- **WHAT-comments are forbidden** (e.g. `// increment counter` over `counter += 1`). Decorative preludes, history-only notes, and forward-promise comments are also forbidden.
- **File headers** carry an evergreen description of the file's role only — no `// Created for EPIC X / Phase Y` lines.
- The same rule applies to test code: no phase/EPIC refs in test comments OR in `XCTAssert*` / `XCTFail` / `XCTSkip` message strings (those are read in failure output and must be self-explanatory).

### Commits & provenance

- Commit message + PR description carry the WHY of the change.
- `git log` / `git blame` / `Tasks/<status>/<task_id>/` folder carry the timeline.
- Production code carries the *current* invariants and constraints — not the journey that led to them.

## Stack

- UI: <SwiftUI | UIKit | AppKit>
- Async: <async/await | Combine | RxSwift>
- DI: <Swinject | Factory pattern (see skill di-module-assembly) | manual>
- Architecture: <MVVM+Coordinator | VIPER | Clean Architecture | MVC>
- Platform: <iOS 16+ | macOS 13+ | iOS+macOS>
- Tests: <XCTest | Quick+Nimble>

## Mode

manual

## Progress

normal

(how much the orchestrator narrates a profile run: `quiet` — the final report only;
`normal` — the stage-to-agent plan once, then a report after every stage; `live` — reserved
for a per-agent ticker that is not built yet, so today it renders exactly as `normal`.
This setting governs reporting only — the between-stage confirmations of `manual` mode are
unaffected by it.)

## Modules

(optional: list of modules with per-module stack, e.g.: "- Core: /Packages/Core — Combine, manual DI")

## EstimationDeltas

(optional: project-specific overrides for `feature-estimation`; leave empty until the calibration log `Tasks/_calibration/estimation-log.md` shows repeatable data across ≥3–5 finished features. Updates are proposed from that log, never written silently.)

## DeliveryMode

manual

(optional: keep `manual` by default; change this value only when the project should produce the additional estimation range documented by `feature-estimation`)

## AILeverage

(optional: project-specific overrides for AI leverage classes used by `feature-estimation`; leave empty until the calibration log `Tasks/_calibration/estimation-log.md` shows repeatable per-class observed divisors across ≥3–5 finished AI-assisted features. Updates are proposed from that log, never written silently.)

## Paths

(optional: "- Sources: /Sources", "- Tests: /Tests")

## Orchestration

The full skill map and dependencies between skill groups — see the swift-toolkit README ("Skills as a system").

Task routing, profile, and stage logic lives in skills:

- `swift-toolkit:orchestrator` — picks the profile by `TASK_TYPE`, determines the start point, dispatches stages
- `swift-toolkit:workflow-feature|bug|refactor|test|review|research|epic` — profile procedures
- `swift-toolkit:task-new|task-move|task-status` — task management
- `swift-toolkit:swift-setup` — configures swift-toolkit in an existing project (creates `CLAUDE-swift-toolkit.md` from template, inserts `@./CLAUDE-swift-toolkit.md` import into `CLAUDE.md`, creates `Tasks/`)
- `swift-toolkit:swift-lang` — switches the project's prompt language

Each profile also has a workflow script (`workflows/profile-*.js`) running the same stages as code; the orchestrator uses it where the host has the `Workflow` tool and falls back to the skill where it does not. Two consequences worth knowing: agents inside a workflow run in `acceptEdits`, so their file edits apply without a prompt whatever permission mode the session is in, and on the Pro plan workflows stay off until enabled in `/config`.

Slash commands:
- task management: `/task-new`, `/task-run`, `/task-continue`, `/task-redo`, `/task-restart`, `/task-move`, `/task-status`
- toolkit setup: `/swift-init` (new project from scratch), `/swift-setup` (attach toolkit to existing project)
- language: `/swift-lang <code>` (switch between `en` and `ru`)

NL phrases continue to work: `create task: ...`, `run 001`, `continue 001`, `move 001 to DONE`, `status 001`, `redo plan for 001`, `set up swift-toolkit`, etc. — the matching skill activates via triggers in its `description`.
