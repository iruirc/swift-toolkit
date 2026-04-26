---
description: Создать новый Swift-проект (iOS/macOS app или SPM package)
argument-hint: <описание проекта>
---

Активируй агент `@swift-toolkit:swift-init` через Task tool (`subagent_type=swift-toolkit:swift-init`) с аргументами: $ARGUMENTS

Агент сгенерирует структуру нового Swift-проекта (Xcode/SPM), настроит SwiftLint и базовый CLAUDE.md. Для подключения swift-toolkit к **уже существующему** проекту используй `/swift-setup`.
