# swift-toolkit

Набор скиллов, агентов и слэш-команд для Claude Code, превращающий ассистента в дисциплинированного iOS/macOS-разработчика. Покрывает архитектурный выбор, реализацию по паттерну, DI, cross-cutting слои (errors / network / persistence), модуляризацию через SPM и оркестрацию задач (FEATURE / BUG / REFACTOR / TEST / REVIEW / EPIC).

## Подключение

- **Новый проект с нуля** — `/swift-init` (создаёт iOS/macOS app или SPM-пакет, заполняет `CLAUDE.md`, разворачивает `Tasks/`).
- **Существующий проект** — `/swift-setup` (копирует шаблон `CLAUDE.md`, заполняет стек через диалог, создаёт `Tasks/`).
- Дальше — управление задачами через слэш-команды (`/task-new`, `/task-run`, `/task-continue`, `/task-redo`, `/task-restart`, `/task-move`, `/task-status`) или NL-фразы («создай задачу: …», «запусти 001», «продолжи 001», «статус 001»).

---

## Skills as a system

Скиллы лежат плоско в `skills/`, но логически разбиваются на **семь групп**. Связи между группами не произвольны: одни решения принимаются независимо друг от друга (parallel decisions), другие — последовательно (выбор архитектуры → конкретные паттерны).

### 0. Meta — точка входа

| Skill | Назначение |
|---|---|
| [`architecture-choice`](skills/architecture-choice/SKILL.md) | Компас: 5 осей (команда / срок жизни / сложность домена / UI-фреймворк / тесты) → одна из 9 строк Decision Matrix. Указывает на конкретный `arch-*`, не заменяет его. Запускается один раз на проект. |

**Запускать первым** при бутстрапе или крупном рефакторинге, если `CLAUDE.md → ## Стек` пуст.

### 1. Архитектурные паттерны (выбираешь **один** на проект)

| Skill | Когда |
|---|---|
| [`arch-mvc`](skills/arch-mvc/SKILL.md) | Прототипы, мелкие CRUD-утилиты, маленькая команда. Содержит триггеры миграции на MVVM/VIPER. |
| [`arch-mvvm`](skills/arch-mvvm/SKILL.md) | Default для большинства команд. 5 binding-подходов (Closures / Combine / async-await / `@Observable` / RxSwift). |
| [`arch-viper`](skills/arch-viper/SKILL.md) | Очень большие команды, строгий контракт между ролями. Default Interactor — async/await. |
| [`arch-clean`](skills/arch-clean/SKILL.md) | Сложный домен, длинный срок жизни, явные Use Cases, тестируемость каждого слоя. |
| [`arch-tca`](skills/arch-tca/SKILL.md) | SwiftUI-only, fluent team, state machines, exhaustive testing. Заменяет и архитектуру, и навигацию. |

### 2. Навигация (выбираешь по UI-фреймворку, **независимо** от архитектуры)

| Skill | Когда |
|---|---|
| [`arch-coordinator`](skills/arch-coordinator/SKILL.md) | UIKit-first проекты. Child-coordinators, Router, deep links, hybrid с SwiftUI через `UIHostingController`. |
| [`arch-swiftui-navigation`](skills/arch-swiftui-navigation/SKILL.md) | SwiftUI-first проекты. `NavigationStack` + `NavigationPath`, `@Observable Router`, `@Environment`-навигация, hybrid с UIKit. |

> TCA свою навигацию покрывает сам (`@Presents`, `StackState`/`StackAction`) — `arch-coordinator` / `arch-swiftui-navigation` не нужны.

### 3. DI (parallel decision: container vs manual + конкретная библиотека)

| Skill | Назначение |
|---|---|
| [`di-composition-root`](skills/di-composition-root/SKILL.md) | **Где** собирается граф (SceneDelegate / AppDelegate / `@main App`). Сравнение container vs manual, sync/async bootstrap, scope strategies. DI-framework agnostic. |
| [`di-module-assembly`](skills/di-module-assembly/SKILL.md) | Factory-паттерн (CoordinatorFactory / ModuleFactory) — связывает DI с Coordinator-ами без Service Locator. |
| [`di-swinject`](skills/di-swinject/SKILL.md) | Swinject-специфика: scopes, registrations, Assembly. |
| [`di-factory`](skills/di-factory/SKILL.md) | FactoryKit (hmlongco): property-wrapper injection, scopes, modular containers, contexts. |
| [`pkg-spm-design`](skills/pkg-spm-design/SKILL.md) | Границы SPM-пакетов (Feature / Library / API-Contract / Engine-SDK). Когда выносить и что делать публичным. |

### 4. Cross-cutting слои (нужны почти всегда, **независимо** от архитектуры)

| Skill | Назначение |
|---|---|
| [`error-architecture`](skills/error-architecture/SKILL.md) | Per-layer error types, маппинг между слоями, presentation strategy, PII-safe logging, retry/cancellation. |
| [`net-architecture`](skills/net-architecture/SKILL.md) | `HTTPClient` protocol как boundary, framework comparison (URLSession/Alamofire/Moya/Get), interceptors, retry, pagination, WebSocket, кэш. |
| [`net-openapi`](skills/net-openapi/SKILL.md) | `swift-openapi-generator`: SPM-плагин, обёртка генерируемого `Client` в свой `APIClient`, custom transport, mocking. |
| [`persistence-architecture`](skills/persistence-architecture/SKILL.md) | Repository как граница, выбор хранилища (Core Data / SwiftData / GRDB / Realm / UserDefaults / files / Keychain), threading, reactive queries, CloudKit, encryption. |
| [`persistence-migrations`](skills/persistence-migrations/SKILL.md) | Миграции схем (CD lightweight/heavyweight, SwiftData VersionedSchema, GRDB DatabaseMigrator, Realm migrationBlock), Codable evolution, backup, telemetry. |

### 5. Binding tools — **не архитектуры**, а инструменты внутри них

| Skill | Назначение |
|---|---|
| [`reactive-combine`](skills/reactive-combine/SKILL.md) | Combine как event-stream / UI-binding инструмент. Архитектура выбирается отдельно (`arch-mvvm` / `arch-clean` / `arch-tca`). |
| [`reactive-rxswift`](skills/reactive-rxswift/SKILL.md) | RxSwift как event-stream / UI-binding инструмент. Архитектура выбирается отдельно (`arch-mvvm` / `arch-clean` / `arch-viper`). |

### 6. Оркестрация задач (внутренняя «кухня» toolkit-а)

| Skill | Назначение |
|---|---|
| [`orchestrator`](skills/orchestrator/SKILL.md) | Маршрутизирует запрос в нужный профильный воркфлоу, резолвит точку старта, управляет стадиями. |
| `workflow-feature` / `workflow-bug` / `workflow-refactor` / `workflow-test` / `workflow-review` / `workflow-epic` | Процедуры профилей (Research → Plan → Execute → Validation → Review → Done). Активируются `orchestrator`-ом, не вызываются напрямую. |
| `task-new` / `task-move` / `task-status` | Ведение `Tasks/` (создание, перенос между статусами, прогресс). |
| `swift-setup` | Настройка toolkit-а в существующем проекте. |

---

## Как группы связаны

```
                  architecture-choice (meta, один раз на проект)
                            │
                            ▼
              ┌─────────────┴─────────────┐
              │                           │
        arch-* (один)              parallel decisions:
              │                    ─────────────────────
              │                     • DI (di-*)
              │                     • Navigation (arch-coordinator | arch-swiftui-navigation)
              │                     • Modularization (pkg-spm-design)
              │                     • Cross-cutting (error- / net- / persistence-)
              ▼                     • Binding (reactive-*)
        Реализация фич
              │
              ▼
        orchestrator + workflow-* + task-*
```

**Ключевые правила:**

- `architecture-choice` — мета-уровень. Запускается один раз. Дальше работают конкретные `arch-*`.
- `arch-coordinator` ↔ `arch-swiftui-navigation` — выбираются по UI-фреймворку, **не** по архитектуре. Можно сменить навигацию, не трогая `arch-mvvm`.
- DI — отдельное решение от архитектуры. Любой `arch-*` совместим с любым `di-*` (или с manual graph).
- `reactive-combine` / `reactive-rxswift` — это **инструменты**, а не архитектуры. Не путать с `arch-*`.
- Cross-cutting (`error-architecture`, `net-architecture`, `persistence-architecture`) — нужны независимо от выбранного `arch-*`.
- TCA — исключение: заменяет и архитектуру, и навигацию (свои `@Presents` / `StackState`).

---

## Агенты

Лежат в `agents/`. Каждый — специализированная роль с собственным набором релевантных скиллов в Skills Reference:

| Агент | Роль |
|---|---|
| `swift-init` | Бутстрап нового проекта |
| `swift-architect` | Дизайн архитектуры и ревью архитектурных решений |
| `swift-developer` | Реализация фич и багфиксов |
| `swift-refactorer` | Рефакторинг без изменения поведения |
| `swift-reviewer` | Code review |
| `swift-tester` | Генерация unit/integration тестов |
| `swift-diagnostics` | Поиск багов, репродукция, инструментирование |
| `swift-security` | OWASP Mobile Top-10 аудит |

---

## Roadmap

Текущее состояние и пробелы — в [`docs/skills-roadmap.md`](docs/skills-roadmap.md).
