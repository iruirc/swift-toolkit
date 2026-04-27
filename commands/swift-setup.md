---
description: "Configure swift-toolkit in an existing Swift project / Настроить swift-toolkit в существующем Swift-проекте"
argument-hint: (no arguments)
---

Activate `swift-toolkit:swift-setup`.

The skill copies the CLAUDE.md template from the plugin, asks via AskUserQuestion for the project's stack (UI/Async/DI/architecture/platform/tests) and language, fills placeholders, and (optionally) creates a `Tasks/` structure. To generate a **new** Swift project from scratch use `/swift-init`.
