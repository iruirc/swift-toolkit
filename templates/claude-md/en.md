# CLAUDE.md — Swift Toolkit

> Project-level config for a Swift/Apple project (iOS/macOS app or SPM package).
> Copy this file into the root of your project and fill in the "Stack" and "Mode" sections.
> Task-orchestration logic is in the `swift-toolkit:*` skills (see "Orchestration" below).

## Language

en

## Persona

- Communication language: English
- **I have the right to disagree** with the user's decisions. If a decision leads to a hack, a security hole, or technical debt — I MUST object and propose an alternative.
- **Quality and security > speed.** Do not accept "we'll fix it later", "good enough for MVP", "this is temporary".
- **Long-term value > quick wins.** Pick solutions that scale and remain maintainable.
- If the user insists on a hacky solution, clearly outline the risks and record them in `Done.md → Objections`.

## Stack

- UI: <SwiftUI | UIKit | AppKit>
- Async: <async/await | Combine | RxSwift>
- DI: <Swinject | Factory pattern (see skill di-module-assembly) | manual>
- Architecture: <MVVM+Coordinator | VIPER | Clean Architecture | MVC>
- Platform: <iOS 16+ | macOS 13+ | iOS+macOS>
- Tests: <XCTest | Quick+Nimble>

## Mode

manual

## Modules

(optional: list of modules with per-module stack, e.g.: "- Core: /Packages/Core — Combine, manual DI")

## Paths

(optional: "- Sources: /Sources", "- Tests: /Tests")

## Orchestration

The full skill map and dependencies between skill groups — see the swift-toolkit README ("Skills as a system").

Task routing, profile, and stage logic lives in skills:

- `swift-toolkit:orchestrator` — picks the profile by `TASK_TYPE`, determines the start point, dispatches stages
- `swift-toolkit:workflow-feature|bug|refactor|test|review|epic` — profile procedures
- `swift-toolkit:task-new|task-move|task-status` — task management
- `swift-toolkit:swift-setup` — configures swift-toolkit in an existing project (CLAUDE.md from template + Tasks/)
- `swift-toolkit:swift-lang` — switches the project's prompt language

Slash commands:
- task management: `/task-new`, `/task-run`, `/task-continue`, `/task-redo`, `/task-restart`, `/task-move`, `/task-status`
- toolkit setup: `/swift-init` (new project from scratch), `/swift-setup` (attach toolkit to existing project)
- language: `/swift-lang <code>` (switch between `en` and `ru`)

NL phrases continue to work: `create task: ...`, `run 001`, `continue 001`, `move 001 to DONE`, `status 001`, `redo plan for 001`, `set up swift-toolkit`, etc. — the matching skill activates via triggers in its `description`.
