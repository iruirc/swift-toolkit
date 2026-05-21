# Commit messages

Single source of truth for the commit message format used by `workflow-*` skills when creating per-phase commits.

## Format

**Conventional Commits.** Every commit follows:

```
<type>(<scope>): <imperative subject>

<optional body — WHY, not WHAT>

<optional footer — e.g. BREAKING CHANGE: ...>
```

## Rules

- **Never include** the task ID, step ID, phase number, ticket number, or epic reference in the subject or body. Provenance lives in `Plan.md` (per-phase checkbox + table row), the branch name, and the PR description. Embedding it in the commit message duplicates state that rots — once the task closes, the marker becomes archaeology.
- **Subject:** imperative mood ("migrate", "add", "fix" — not "migrates"/"added"/"fixes"), ≤72 chars, lowercase first char after the `:`, no trailing period.
- **Body:** explains WHY (the diff shows WHAT). Wraps at 72 chars. Optional for trivial one-line subjects (a single typo fix). Required when the change is non-obvious or carries risk worth recording.
- **Bullet list at the end of body** is permitted for enumerating the key sub-changes of a larger commit.
- **Project override:** if `git log` shows the project uses a different convention for similar tasks, follow that convention instead. The agent matches existing history; this spec is the default when no project convention is detectable.

## Types

| Type | When |
|---|---|
| `feat` | New user-visible functionality |
| `fix` | Bug fix |
| `refactor` | Structural change with no behavior change |
| `test` | Test-only additions or modifications |
| `docs` | Documentation only |
| `chore` | Build, tooling, config, dependency updates |
| `perf` | Performance improvement (no behavior change) |
| `style` | Formatting, whitespace, imports — no semantic change |

## Scope

Optional but recommended for monorepos or multi-package workspaces. Common scopes:

- Module / package name: `(MediaPlayer)`, `(Networking)`, `(Onboarding)`
- Cross-cutting area: `(deps)`, `(ci)`, `(workspace)`

If the change touches multiple modules at the same layer, prefer the most specific common scope; if there is no common scope, omit scope.

## Examples

### Refactor with body

```
refactor(MediaPlayer): migrate manual KVO to block-based observation

Manual addObserver with UnsafeMutableRawPointer is fragile — double-remove
throws NSInternalInconsistencyException. Block-based observe() returns
NSKeyValueObservation tokens stored in an array; cleanup is deterministic.

- Replace UnsafeMutableRawPointer observers with NSKeyValueObservation
- Drop the manual isObserving guard flag
- Extract KVO handlers into dedicated private methods
```

### Feature (concise)

```
feat(domain): add ProjectListUseCase

Encapsulates pagination + filtering that previously lived in the
Presenter. Lets the ViewModel observe a single async stream instead
of orchestrating three repositories.
```

### Bug fix (one-liner OK when subject is self-explanatory)

```
fix(AuthMiddleware): use < not <= when checking token expiry boundary
```

### Test

```
test(PaginationCalculator): cover boundary and overflow inputs

Locks in the expected page-range output for empty / single-page / max-page
inputs — guards against regressions when the calculator is refactored.
```

### Docs

```
docs(README): document minimum Swift toolchain requirement
```

### Chore

```
chore(deps): bump SnapKit to 5.7.0

Picks up the new constraintsEqualToSet API used by the upcoming
PaywallView layout work.
```

## Anti-examples

These are **forbidden**:

- `042/01.step: phase 4 — migrate KVO to block-based` — embeds task/step/phase IDs
- `Phase 4 done` — no type, no scope, vague subject
- `wip` / `fix` / `update` — useless subject, no scope, no WHY
- `EPIC 042 §01 Phase 4 — migrate manual KVO` — task references belong in `Plan.md` and PR
- `fix: fixes the bug` — duplicates type in subject, no WHY
- `Refactor: Migrate Manual KVO.` — wrong case, trailing period

## Comment hygiene parity

The same provenance rule applies to **code comments**: never embed task/phase/EPIC/ticket references in production code or test code. See per-workflow Comment hygiene sections and `agents/swift-developer.md → ## Comment Policy`. Commit messages and PR descriptions carry the WHY of the change; code comments stay evergreen.
