---
description: Создать новый Swift-проект (iOS/macOS app или SPM package)
argument-hint: <описание проекта>
---

Активируй агент `@swift-toolkit:swift-init` через Task tool (`subagent_type=swift-toolkit:swift-init`) с аргументами: $ARGUMENTS

Агент сгенерирует **один артефакт** — приложение (iOS/macOS) либо SPM-пакет — настроит SwiftLint и базовый CLAUDE.md. Для **многомодульного проекта** запусти команду несколько раз в нужных папках (пакеты могут лежать где угодно на диске), `.xcworkspace` собери в Xcode (`File → New → Workspace`). Для подключения swift-toolkit к **уже существующему** проекту используй `/swift-setup`.
