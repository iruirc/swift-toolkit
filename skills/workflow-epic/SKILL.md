---
name: workflow-epic
description: "Воркфлоу профиля EPIC: Research → Plan → Execute (decomposition или pure-research) → Done. Активируется swift-toolkit:orchestrator-ом, не вызывается пользователем напрямую."
---

# Workflow Epic

Профильный воркфлоу для задач с `[TASK_TYPE] = EPIC`. В отличие от других workflow-* эпик имеет ветвление на стадии Plan: **decomposition** (разбиение на `.step/` подпапки и их последовательное исполнение) или **pure_research** (Research.md — финальный артефакт, реализации нет). Скилл получает уже резолвленный контракт от оркестратора и не пытается доразрешать параметры самостоятельно.

## 1. Контракт входа

Скилл вызывается `swift-toolkit:orchestrator`-ом через `Skill` tool с структурированными `args` в формате `key=value`, разделённых только переводом строки.

Структура полей описана в `swift-toolkit:orchestrator` (раздел **Outbound Contract**). Workflow-epic принимает все поля заполненными — invariant.

Если пришло пустое обязательное поле — workflow-epic не пытается восстановить, а возвращает `{status: error, reason: missing field <name>}` обратно в оркестратор.

Ключевые поля и их EPIC-специфика:
- `start_stage`, `end_stage`, `stage_scope` — определяют, какие стадии исполнять.
- `start_phase` — для EPIC означает **`step_id`** (например, `start_phase=2.step` или `start_phase=composition-model.step`), а не фазу внутри стадии. Стадии Research/Plan не декомпозируются на phases в обычном смысле — единица возобновления внутри Execute это step.
- `stage_scope=single` — для EPIC означает **«один step»**, а не одну стадию. Используется при `redo` или точечном перезапуске одного step-а.
- `mode` — `manual` / `auto` (см. секции 3 и 4). Режим эпика наследуется в каждый step при делегировании, если у step-а в его собственном `Task.md` нет своего `[WORKFLOW_MODE]`.
- `stack` — передаётся субагентам Research/Plan и наследуется в step-ы (если у них нет собственного `## 4. [Stack]`).
- `need_test`, `need_review` — на уровне эпика управляют только Plan/Research; на уровне step-ов решение принимается их собственным workflow-* по их Task.md.
- `archive_paths` — пути к уже сделанным бэкапам (бэкап делает оркестратор ДО вызова; workflow-epic их не создаёт).
- `epic_dispatch_mode` — **дополнительное опциональное поле, специфичное для EPIC**: `push` (default) или `pull`. Выставляется оркестратором по результатам pre-flight проверки nested `Skill` invocation (см. секцию 2.3, Execute).

**Диапазон выполнения.** Стадии выполняются в порядке Research → Plan → Execute → Done, начиная с `start_stage` и до `end_stage` включительно. Если на Plan стадии выбрана ветка **pure_research** — Execute пропускается, workflow сразу переходит к Done с `last_completed_stage=Plan` и `branch=pure_research`. Если `end_stage=null` — до конца профиля. Если `end_stage` указана и она раньше `start_stage` в порядке — это ошибка контракта, возврат `{status: error, reason: "end_stage before start_stage"}`.

**Scope.** `stage_scope` определяет ширину выполнения:
- `single` — выполняется только `start_stage`. Для Execute это означает «один step» (тот, что указан в `start_phase=<step_id>`).
- `forward` — выполняется `start_stage` и все последующие до `end_stage` (или до конца профиля).
- `all` — эквивалент `forward` с `start_stage = Research`. Используется при `action=restart-full`.

## 2. Stages

- **Research** — `swift-architect`. Артефакт: `Research.md` в папке эпика. Цель: широкое исследование темы (контекст, акторы, ограничения, технологические опции, связанные модули). На выходе Research должен дать понимание: **нужна ли декомпозиция** (большая инициатива требует разбиения на исполняемые куски) **или достаточно «чистого исследования»** (Research.md сам по себе финальный артефакт, реализации не будет).

- **Plan** — `swift-architect`. **Две ветки:**

  **Ветка А — Decomposition.**
  - Артефакт: `Plan.md` с прогресс-таблицей **`.step/` подпапок** (а не фаз внутри одного профиля).
  - Каждый step описан как отдельная задача: имеет свой `[TASK_TYPE]` (FEATURE/BUG/REFACTOR/TEST/EPIC — да, рекурсивный EPIC возможен), свой `[STATUS]` ∈ {TODO, ACTIVE, DONE, DEFERRED, BLOCKED, SKIPPED}, опциональный `[WORKFLOW_MODE]`, свой `## 4. [Stack]` (или наследует от эпика).
  - Step-папки создаются физически: `Tasks/<STATUS>/<epic-id>-<slug>/1.step/`, `2.step/`, …, `composition-model.step/` (любые имена с суффиксом `.step`). Внутри каждой — собственный `Task.md`. Создание физических папок — обязанность `swift-toolkit:task-new` (см. секцию 6).
  - Прогресс-таблица в Plan.md перечисляет step-ы в порядке исполнения с колонками: `step_id | TASK_TYPE | [STATUS] | краткое описание | артефакт`.

  **Ветка Б — Pure research.**
  - Артефакт: `Research.md` дополняется/дорабатывается финальной версией. `Plan.md` опционально создаётся как «research-roadmap» (что ещё нужно изучить, без декомпозиции на исполняемые steps).
  - Workflow сразу переходит к Done (Execute стадия пропускается, в выходном контракте `branch=pure_research`, `last_completed_stage=Plan`, `completed_steps=[]`).

  Решение о ветке принимается на основании Research.md (фиксируется в нём явным разделом «Решение по декомпозиции»). Workflow-epic читает это решение и действует согласно ему — **сам не выбирает ветку** (см. секцию 6).

- **Execute** (только при ветке А — Decomposition). Обход `.step/` подпапок последовательно — по порядку префикса (`1.step` → `2.step` → … для числовых; для именованных — по порядку, зафиксированному в `Plan.md`). **Параллельно step-ы НЕ запускаются** — только последовательно, ради предсказуемости и чистого восстановления состояния.

  Для каждого step:
  - Прочитать `<step>/Task.md`, извлечь `[STATUS]` и `[TASK_TYPE]`.
  - Если `[STATUS]` ∈ {DEFERRED, BLOCKED, SKIPPED, DONE} — пропустить, перейти к следующему. Записать пропуск в `skipped_steps` выходного контракта с причиной.
  - Иначе — делегировать step (см. ниже push vs pull).
  - Если step вернул `status=error` — остановить обход, зафиксировать в `failed_steps`, вернуть управление оркестратору со статусом `partial` (если хотя бы один step уже завершён) или `error` (если упал первый же исполняемый step).
  - Если step вернул `status=cancelled` (пользователь отказался в его AUQ) — остановить обход, статус `partial` или `cancelled`.

  **Push vs Pull dispatch модели.**

  - **Push (рекомендованный default):** workflow-epic вызывает `Skill` tool с `name=swift-toolkit:orchestrator` и args, описывающими step (фактически как новую задачу: `task_id=<step_id>`, контекст эпика наследуется в args). Дожидается возврата result от вложенного оркестратора, фиксирует исход и переходит к следующему step-у. Применяется, когда оркестратор pre-flight подтвердил, что nested `Skill` invocation работает.

  - **Pull (fallback):** workflow-epic **не вызывает** orchestrator. Вместо этого: проходит все `.step/` папки, собирает упорядоченный список `[{step_id, task_id, profile, mode, …}]`, возвращает его в оркестратор через `Контракт выхода` в поле `pending_steps`. Оркестратор сам последовательно диспетчеризует каждый step как обычные задачи. Используется, когда push не работает или оркестратор явно запросил pull.

  **Как выбирается режим:**
  - Если в args пришёл `epic_dispatch_mode=push` — использовать push.
  - Если `epic_dispatch_mode=pull` — использовать pull (skip фактического запуска step-ов, заполнить `pending_steps`).
  - Если поле отсутствует — default `push`.

  Документированный happy path — push. Pull существует только как fallback на случай, если nested `Skill` invocation не работает в текущем Claude Code.

- **Done** — финальный отчёт `Done.md` эпика:
  - Какие step-ы завершены (со ссылками на их `Done.md`).
  - Какие пропущены и почему (DEFERRED/BLOCKED/SKIPPED/DONE_already).
  - Какие BLOCKED требуют действий пользователя (явный список с описанием блокера).
  - Общий прогресс эпика (X из Y step-ов завершены).
  - Возражения (если в каких-то step-ах пользователь настоял на спорных решениях — агрегируется из их `Done.md`).
  - Если ветка Б (pure_research) — Done.md короткий, ссылается на `Research.md` как на финальный артефакт; раздел про step-ы пуст.

## 3. Manual режим

После каждой стадии (Research, Plan) и **после каждого step-а в Execute** оркестратор задаёт пользователю `AskUserQuestion`: «<stage> / step <step_id> готова. Перейти к следующей? [Yes / Edit / No]».

Workflow-epic **не делает `AskUserQuestion` сам** — он возвращает управление оркестратору после завершения стадии или step-а с `next_recommended_action`. Решение о паузе, диалоге и обсуждениях, которые пишутся в `Questions.md` эпика, — зона ответственности оркестратора.

В push-модели за паузы между стадиями step-а отвечает вложенный вызов оркестратора (он сам диспетчеризует step как обычную задачу). Workflow-epic паузит только между **самими step-ами**, не внутри них.

## 4. Auto режим

Без пауз. Step-ы в Execute выполняются последовательно один за другим; прерывание только если step вернул `status=error` или `status=cancelled`. Финальный коммит, если оркестратор инициирует commit-flow после Done — всегда согласуется с пользователем (это ответственность оркестратора, не workflow-epic).

## 5. Контракт выхода (расширенный)

Контракт выхода EPIC расширен полями про step-ы и ветку. После каждой стадии (в `manual` режиме) или после полного прохода (в `auto` режиме) workflow-epic возвращает в оркестратор JSON-подобную структуру:

```
{
  status: ok | error | cancelled | interrupted | partial,
  last_completed_stage: Research | Plan | Execute | Done,
  branch: decomposition | pure_research,
  artifact_path: <путь к Done.md или Research.md>,
  next_recommended_action: continue | stop | ask_user,
  notes: <свободный текст, опциональный>,

  # Для ветки decomposition — расширенные поля:
  completed_steps: [{step_id, task_id, status: ok|error|cancelled|interrupted}],
  skipped_steps:   [{step_id, task_id, reason: DEFERRED|BLOCKED|SKIPPED|DONE_already}],
  failed_steps:    [{step_id, task_id, error_reason}],

  # Для pull-модели:
  pending_steps:   [{step_id, task_id, profile, mode, stack, ...}]
}
```

Семантика полей:
- `status=ok` — все исполняемые step-ы (или одиночная стадия) завершены успешно.
- `status=error` — фатальная ошибка (например, упал первый же step, или контракт нарушен).
- `status=cancelled` — пользователь явно отказался продолжать. Штатный исход.
- `status=interrupted` — выполнение прервано техническим сбоем (таймаут, потеря субагента).
- `status=partial` — **специфика EPIC**: часть step-ов завершена успешно, часть failed/blocked/cancelled. Оркестратор решает, что показать пользователю и продолжать ли.
- `branch=decomposition` — Plan стадия выбрала декомпозицию, есть step-ы.
- `branch=pure_research` — Plan выбрала pure research, `completed_steps`/`skipped_steps`/`failed_steps`/`pending_steps` пустые.
- `last_completed_stage` — последняя реально завершённая стадия (для pure_research максимум — `Plan`).
- `artifact_path` — путь к ключевому артефакту: `Done.md` для decomposition, `Research.md` (или `Plan.md` если есть research-roadmap) для pure_research.
- `next_recommended_action=continue` — можно сразу запускать следующую стадию или следующий step; `stop` — финиш или фатальная ошибка; `ask_user` — нужно подтверждение (например, после `partial` или после step с `CHANGES_REQUESTED` в его Review).
- `pending_steps` — заполнен только в pull-модели; упорядоченный список step-ов, которые оркестратор должен последовательно диспетчеризовать сам. В push-модели всегда `[]`.

На основании этого оркестратор решает: продолжить, прервать, спросить пользователя, диспетчеризовать pending_steps.

## 6. Что workflow-epic НЕ делает

- НЕ маршрутизирует — выбор профиля сделан в оркестраторе до вызова.
- НЕ читает `Task.md` эпика для определения стека/режима — всё пришло в `args`.
- НЕ создаёт `.step/` подпапки сам — это делает `swift-toolkit:task-new` (его дёргает оркестратор или пользователь перед запуском EPIC, либо стадия Plan инструктирует архитектора создать step-папки через task-new).
- НЕ модифицирует `[STATUS]` step-ов — это работа `swift-toolkit:task-move` (вызывается субагентом внутри каждого step при его завершении).
- НЕ принимает решения о ветке pure_research vs decomposition — это решение фиксируется в `Research.md` стадии Research (раздел «Решение по декомпозиции»), workflow-epic просто читает и действует.
- НЕ диспетчеризует step-ы параллельно — только последовательно (для предсказуемости и чистого resume).
- НЕ создаёт бэкапы в `_archive/` — это сделал оркестратор до передачи управления; пути уже в `archive_paths`.
- НЕ задаёт `AskUserQuestion` — это делает оркестратор между стадиями и между step-ами в `manual` режиме.
- НЕ согласует коммит с пользователем — этим занимается оркестратор после возврата `next_recommended_action`.
