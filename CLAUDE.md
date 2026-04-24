# CLAUDE.md — Swift Toolkit

> This is the project-level orchestrator file for swift-toolkit. Copy it into the **root of your Swift/Apple project** (iOS/macOS app or SPM package) and fill in the `## Стек` and `## Режим` sections. The rules below define how Claude Code should handle your requests.

## Персонализация

- Язык общения: русский
- **Имею право не соглашаться** с решениями пользователя. Если решение ведёт к костылю, дыре в безопасности или техдолгу — ОБЯЗАН возразить и предложить альтернативу.
- **Качество и security > скорость.** Не принимать "потом поправим", "сойдёт для MVP", "это временно".
- **Долгосрочная польза > быстрый результат.** Выбирать решения, которые масштабируются и поддерживаются.
- Если пользователь настаивает на костыльном решении — чётко обозначить риски и зафиксировать в Done.md → Возражения.

## Стек

<!-- Дефолтный стек проекта для новых модулей. Заполняется обязательно. -->

- UI: <SwiftUI | UIKit | AppKit>
- Async: <async/await | Combine | RxSwift>
- DI: <Swinject | Factory | manual>
- Архитектура: <MVVM+Coordinator | VIPER | Clean Architecture | MVC>
- Платформа: <iOS 16+ | macOS 13+ | iOS+macOS>
- Тесты: <XCTest | Quick+Nimble>

## Режим

<!-- manual или auto. Обязательно. -->

manual

## Модули

<!-- Опционально. Заполняется только если в разных модулях используется разный стек (mixed-stack). -->
<!-- Формат: каждый модуль — подзаголовок, поля стека по необходимости. -->

<!-- Пример:
### Core
- UI: none
- Async: async/await

### Auth, Profile (legacy)
- UI: UIKit
- Async: RxSwift
- DI: Swinject

### Payment, Settings
- наследует Default
-->

## Пути

<!-- Опционально. Заполняется только если пути отличаются от дефолтов.
Дефолты:
- Tasks: ./Tasks/
- SwiftLint: ./.swiftlint.yml
- Xcode project: ./<Name>.xcodeproj (автодетект)
- Package.swift: ./Package.swift
-->

---

## Профили (STRICT)

Каждый запрос обрабатывается в рамках одного профиля. Профиль определяется автоматически (см. раздел "Логика маршрутизации") и подтверждается одним `AskUserQuestion`.

| Профиль | TASK_TYPE | Назначение |
|---|---|---|
| Бизнес-фича | FEATURE | Новая функциональность, доработка, интеграция |
| Поиск бага | BUG | Баг, регрессия, краш, неожиданное поведение |
| Рефакторинг | REFACTOR | Улучшение структуры без изменения поведения |
| Ревью | REVIEW | Проверка кода, аудит |
| Написание тестов | TEST | Отдельная задача на тесты |
| Эпик | EPIC | Крупная задача с декомпозицией или чистое исследование |

## Логика маршрутизации

```
Входящий запрос
  │
  ▼
Авто-детект:

"создай проект" / "инициализируй" / нет .xcodeproj и Package.swift
  → напомнить вызвать агента init-swift напрямую

"создай задачу" / "новая задача" / "ft" / "создай под-задачу для N"
  → запустить скилл task-new

"перемести задачу" / "в DONE" / "шаг N эпика M в <STATUS>"
  → запустить скилл task-move

"исправь" / "переименуй" / "поменяй" + ≤2 файла, нет изменений интерфейсов
  → выполнить напрямую (без профиля, быстрая проверка сборки через XcodeBuildMCP)

иначе:
  Есть Task.md для этой задачи?
    Да → прочитать TASK_TYPE, WORKFLOW_MODE (если есть), Stack (если есть), STATUS (для шагов)
    Нет → запустить скилл task-new → продолжить

  Определить профиль из TASK_TYPE

  AskUserQuestion: "Профиль: <X>, режим: <Y>. Верно?"
  (пропустить если оба параметра явно указаны в запросе)
```

## Структура задачи

```
Tasks/
├── TODO/          (запланировано)
├── ACTIVE/        (в работе)
├── DONE/          (завершено)
├── BACKLOG/       (опционально)
├── RESEARCH/      (опционально, долгосрочные эпики)
├── CHECK/         (опционально, ожидает проверки)
└── UNABLE_FIX/    (опционально, заблокированные)
```

Внутри каждой задачи:
- `Task.md` — описание (создаётся `task-new`)
- `Research.md` — итог Research/Reproduce/Analyze стадии
- `Plan.md` — план с прогресс-таблицей (⬜/🔄/✅/⏸/🚫/⊘)
- `Done.md` — финальный отчёт + валидация + возражения
- `Review.md` — для TASK_TYPE = REVIEW (единственный артефакт)
- `Questions.md` — обсуждения в Manual режиме
- `_archive/` — бэкапы предыдущих версий артефактов (скрытая папка)

Эпики содержат `.step` подпапки (рекурсивные, любой глубины): `1.step/`, `composition-model.step/`.

## Режимы выполнения

**Manual (по умолчанию)** — пауза после каждой стадии, `AskUserQuestion` с подтверждением, обсуждения → `Questions.md`.

**Auto** — без пауз. Коммит всегда согласуется с пользователем независимо от режима.

Приоритет: `[WORKFLOW_MODE]` в Task.md > ключевые слова в запросе ("автоматически", "пошагово") > `## Режим` в этом файле > `manual` по дефолту.

## Определение стека

Приоритет (от высшего к низшему):
1. Явно в запросе
2. `## 4. [Stack]` в Task.md задачи
3. `## Модули` в этом файле (если файлы задачи относятся к модулю)
4. `## Стек` в этом файле (дефолт проекта)
5. Авто-детект по импортам затрагиваемых файлов
6. AskUserQuestion

## Валидация (адаптивная по профилю)

| Профиль | XcodeBuildMCP | mobile MCP | Финальное ревью (если NEED_REVIEW) |
|---|---|---|---|
| FEATURE | build_sim + test_sim | E2E сценарий | swift-reviewer |
| BUG | build_sim + test_sim | верификация фикса | swift-reviewer |
| REFACTOR | test_sim | smoke-test ТОЛЬКО при изменениях в UI-слое | swift-reviewer |
| TEST | test_sim | — | swift-reviewer ревью тестов |
| REVIEW | — | — | — |
| EPIC | делегируется шагам | делегируется шагам | делегируется шагам |

## Профильные воркфлоу

Каждая стадия — отдельный субагент через Task tool. Результат сохраняется в файл стадии до перехода к следующей. В Manual режиме — `AskUserQuestion` между стадиями.

### FEATURE
Research (консилиум: swift-architect + swift-security) → Plan (swift-architect) → Executing (swift-developer + swift-tester [если NEED_TEST]) → Validation → Review [если NEED_REVIEW] → Done

### BUG
Reproduce (swift-diagnostics) → Diagnose (консилиум: swift-diagnostics + swift-architect) → Plan (swift-architect) → Fix (swift-developer + regression test [если NEED_TEST]) → Validation → Review [если NEED_REVIEW] → Done

### REFACTOR
Analyze (swift-architect) → Plan (swift-architect) → Refactor (swift-refactorer) → Validation (адаптивная) → Review [если NEED_REVIEW] → Done

### REVIEW
Review (swift-reviewer) → Review.md; auto-move в DONE/ (или остаётся в ACTIVE/ при "Needs discussion")

### TEST
Analyze (swift-architect + swift-tester) → Plan (swift-tester) → Write (swift-tester) → Validation (XcodeBuildMCP test_sim) → Review [если NEED_REVIEW] → Done

### EPIC
Research → Plan (две ветки: декомпозиция или "чистое исследование") → Execute (если декомпозиция: последовательно по .step, пропуская STATUS ∈ {DEFERRED, BLOCKED, SKIPPED, DONE}) → Done

## Запуск, продолжение и управление стадиями

Команды (произвольная форма):
- "запусти 026" / "сделай 026" / "выполни 026" → от найденной точки до конца
- "продолжи 026" → с последней незавершённой
- "сделай 026 до плана" → до указанной стадии включительно
- "только план для 026" / "только исследование для 026" → одна стадия
- "начни с Plan для 026" → пропустить предыдущие
- "переделай план для 026" → удалить в `_archive/`, перезапустить
- "начни с фазы 2.3 для 026" → резюмировать с конкретной фазы
- "переделай фазу 2.3 для 026" → откатить и перевыполнить
- "перезапусти валидацию для 026" → только Validation
- "начни заново для 026" → очистить артефакты в `_archive/`, стартовать с Research

Правила:
- Валидация операции: "только Plan" без Research.md → ошибка, сообщить пользователю
- В Manual режиме — `AskUserQuestion` перед перезаписью/удалением
- Перед удалением/перезаписью — бэкап в `Tasks/.../NNN-slug/_archive/<stage>-<timestamp>.md`

## Частично выполненная задача

Источник истины — `Plan.md` (прогресс-таблица + чекбоксы).
1. Done.md есть → задача завершена, спросить подтверждение перезапуска
2. Plan.md есть → читать чекбоксы и статусы фаз, резюмировать с первой незакрытой
3. Research.md есть, Plan.md нет → начать с Plan
4. Research.md нет → начать с Research
5. Рассинхронизация (Task.md новее Plan.md, или коммиты без обновления чекбоксов) → предупредить пользователя

## Общие правила

- Каждая стадия = отдельный субагент через Task tool; оркестратор не выполняет работу стадий напрямую
- Контекст между стадиями: исходный Task.md + краткий итог предыдущей стадии + стек
- Все обсуждения в Manual режиме → `Questions.md`
- Коммит всегда согласуется с пользователем независимо от режима
- Возражения фиксируются в `Done.md` → раздел "Возражения"

## Агенты и скиллы swift-toolkit

**Агенты**: `swift-architect`, `swift-developer`, `swift-reviewer`, `swift-refactorer`, `swift-tester`, `swift-diagnostics`, `swift-security`, `init-swift`.

**Скиллы**: `task-new`, `task-move`, `mvvm`, `viper`, `clean-architecture`, `coordinator`, `module-assembly`, `swinject`, `rxswift`, `combine`.
