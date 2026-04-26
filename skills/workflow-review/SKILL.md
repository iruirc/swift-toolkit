---
name: workflow-review
description: "Воркфлоу профиля REVIEW: одиночный проход swift-toolkit:swift-reviewer + auto-move в DONE/ при APPROVED. Активируется swift-toolkit:orchestrator-ом, не вызывается пользователем напрямую."
---

# Workflow Review

Профильный воркфлоу для задач с `[TASK_TYPE] = REVIEW`. Структурно проще остальных воркфлоу: одна содержательная стадия (Review) и детерминированная пост-стадия Auto-move, маршрутизация по полю `[REVIEW_STATUS]`. Скилл получает уже резолвленный контракт от оркестратора и не пытается доразрешать параметры самостоятельно.

## 1. Контракт входа

Скилл вызывается `swift-toolkit:orchestrator`-ом через `Skill` tool с структурированными `args` в формате `key=value`, разделённых только переводом строки.

Структура полей описана в `swift-toolkit:orchestrator` (раздел **Outbound Contract**). Workflow-review принимает все поля заполненными — invariant.

Если пришло пустое обязательное поле — workflow-review не пытается восстановить, а возвращает `{status: error, reason: missing field <name>}` обратно в оркестратор.

Особенности профиля REVIEW (отличия от других воркфлоу):
- `start_stage` — всегда `Review` (других стадий нет; иные значения — ошибка контракта).
- `end_stage` — всегда `Review` или `null` (auto-move — это не стадия профиля, а пост-обработка артефакта).
- `stage_scope` — всегда `single` (workflow никогда не «продолжается» дальше; auto-move применяется автоматически по результату Review, см. секцию 2).
- `start_phase` — не используется (внутри Review нет фаз).
- `need_test`, `need_review` — игнорируются: сам этот профиль и есть ревью; повторно `swift-toolkit:swift-reviewer` себя не вызывает, а тесты выполняются в воркфлоу-донорах (FEATURE/BUG/REFACTOR/TEST).
- `mode` — `manual` / `auto` (см. секции 3 и 4): влияет только на согласование auto-move.
- `stack`, `archive_paths` — стандартно (контекст для `swift-toolkit:swift-reviewer` и информация о бэкапах, сделанных оркестратором).

## 2. Stages

- **Review** — `swift-toolkit:swift-reviewer`. Артефакт: `Review.md` в папке задачи. **Обязательная первая строка** артефакта: `[REVIEW_STATUS] = APPROVED | CHANGES_REQUESTED | DISCUSSION` — это контракт со всеми воркфлоу и оркестратором. Тело `Review.md`: что сделано хорошо, что требует изменений (по severity), открытые вопросы. Подробное описание выходного формата — в `agents/swift-reviewer.md`.

- **Auto-move** — детерминированная пост-стадия. Workflow читает первую строку `Review.md` строго как поле `[REVIEW_STATUS] = <value>` (regex на «начинается с `[REVIEW_STATUS] =`», парсинг значения по «=»). Substring-поиск по телу `Review.md` запрещён. Возможные значения и действия:
  - `APPROVED` → вызвать `swift-toolkit:task-move` для перемещения папки задачи в `Tasks/DONE/`. Если задача уже в `Tasks/DONE/` — остаётся (idempotent).
  - `CHANGES_REQUESTED` → задача остаётся в `Tasks/ACTIVE/`. В `Done.md` (или, если его нет, в отдельной заметке `ChangesRequested.md` рядом с `Review.md`) добавляется секция «Ждёт доработки» со списком конкретных пунктов из `Review.md` (severity Critical/Major).
  - `DISCUSSION` → задача остаётся в `Tasks/ACTIVE/`. Создаётся (или дополняется) `Questions.md` секцией `## <ISO-дата> — Discussion from Review` с цитатами/ссылками на спорные пункты `Review.md`.
  - Любое другое значение или отсутствие первой строки в требуемом формате → `{status: error, reason: "invalid or missing [REVIEW_STATUS] in Review.md"}`.

## 3. Manual режим

После завершения стадии Review оркестратор задаёт пользователю `AskUserQuestion`: «Apply auto-move per `[REVIEW_STATUS]=<value>`? [Yes / Modify / No]».

- `Yes` — workflow-review выполняет auto-move согласно секции 2.
- `Modify` — пользователь правит `Review.md` (например, меняет статус или формулировки), после чего оркестратор перезапускает workflow-review со стадии Review (`action=redo`, `stage_scope=single`).
- `No` — auto-move пропускается; задача остаётся на месте без записей в `Done.md`/`Questions.md`. В выходе фиксируется `notes: "auto-move skipped by user"`.

Workflow-review **сам `AskUserQuestion` не вызывает** — после Review он возвращает управление оркестратору с `next_recommended_action=ask_user`. Решение о паузе и текстовых fallback-ах — зона оркестратора.

## 4. Auto режим

Без пауз. Auto-move выполняется немедленно после завершения Review согласно секции 2, без согласования с пользователем. Workflow-review возвращает один финальный результат с уже применённым auto-move.

Финальный коммит, если оркестратор инициирует commit-flow, согласуется с пользователем независимо от режима — это ответственность оркестратора.

## 5. Контракт выхода

После Review (в `manual` режиме) и после Auto-move (в обоих режимах) workflow-review возвращает в оркестратор JSON-подобную структуру:

```
{
  status: ok | error | cancelled | interrupted,
  last_completed_stage: Review | AutoMove,
  artifact_path: <путь к Review.md>,
  next_recommended_action: stop,
  notes: "[REVIEW_STATUS]=<value>; auto-move: <moved-to-DONE | kept-in-ACTIVE-with-ChangesRequested | kept-in-ACTIVE-with-Questions | skipped-by-user | not-yet-applied>"
}
```

Семантика полей:
- `status=ok` — стадия завершена корректно.
- `status=error` — ошибка контракта (например, некорректный `start_stage`, отсутствует/некорректен `[REVIEW_STATUS]`, фатальный сбой `swift-toolkit:swift-reviewer` или `task-move`).
- `status=cancelled` — пользователь явно отказался продолжать (нажал «No» в AUQ оркестратора). Штатный исход.
- `status=interrupted` — выполнение прервано техническим сбоем или внешним сигналом.
- `last_completed_stage` — `Review`, если auto-move ещё не применён (manual-пауза перед AUQ); `AutoMove`, если auto-move применён или явно пропущен пользователем.
- `artifact_path` — путь к `Review.md` (он остаётся ключевым артефактом профиля даже после перемещения папки в `Tasks/DONE/`).
- `next_recommended_action` — **всегда `stop`**: REVIEW заканчивает цикл и не передаёт управление другим воркфлоу.
- `notes` — фактическое значение `[REVIEW_STATUS]` и совершённое действие auto-move (или причина пропуска).

## 6. Что workflow-review НЕ делает

- НЕ запускает другие воркфлоу. Если `[REVIEW_STATUS] = CHANGES_REQUESTED`, workflow-review **не инициирует** workflow-feature / workflow-bug / workflow-refactor для устранения замечаний — решение об этом принимает пользователь (например, через `task-new` или `action=redo` на исходной задаче).
- НЕ изменяет код проекта. Единственные допустимые изменения файловой системы — `Review.md`, `Done.md` / `ChangesRequested.md`, `Questions.md` и перемещение папки задачи через `task-move`.
- НЕ парсит `Review.md` по содержимому — auto-move решает только по структурированному полю `[REVIEW_STATUS]` в первой строке. Substring-поиск («approved», «LGTM», «changes requested» в теле) запрещён как ненадёжный.
- НЕ переключает свой `stage_scope` — он всегда `single`. Любые `forward` / `all` от оркестратора игнорируются (возврат `{status: error, reason: "stage_scope must be single for REVIEW"}`).
- НЕ маршрутизирует — выбор профиля сделан в оркестраторе до вызова.
- НЕ читает `Task.md` для определения стека/режима — всё пришло в `args`.
- НЕ создаёт бэкапы в `_archive/` — это сделал оркестратор до передачи управления; пути уже в `archive_paths`.
- НЕ задаёт `AskUserQuestion` — это делает оркестратор перед auto-move в `manual` режиме.
- НЕ согласует коммит с пользователем — этим занимается оркестратор после возврата `next_recommended_action`.
