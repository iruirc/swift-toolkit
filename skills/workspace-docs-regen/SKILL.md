---
name: workspace-docs-regen
description: |
  Regenerate marker-delimited sections of workspace docs.
  Use when (en): "regen docs", "refresh workspace docs", "/workspace-docs-regen"
  Use when (ru): "обнови docs", "регенерация docs", "/workspace-docs-regen"
---

# workspace-docs-regen

Regenerates the content between `<!-- WORKSPACE_*_BEGIN -->` / `_END -->` markers across meta-repo + every package. User content outside markers is never touched.

## Language Resolution

Read `## Language` from meta-repo's `CLAUDE-swift-toolkit.md`. Fallback: `en`.

## Modes

| Invocation | Behaviour |
|------------|-----------|
| (default) | Regenerate every marker section in place. Strict-fail on malformed markers. |
| `--check` | Compare canonical regen with on-disk; exit 1 if drift; exit 2 if malformed markers. |
| `--repair` | Run `wsmark::repair` interactively on every file with malformed markers; then run default regen. |
| `--pkg <name>` | Restrict to one package + meta-repo sections referencing it. |
| `--adopt --pkg <name>` | Wrap known section headings (`## Boundary contract`, `## Public API`) with markers if not already wrapped, then regen. |

## Algorithm

1. Locate `workspace.yml` (cwd or ancestors). If absent → emit `error_missing_workspace_yml`, exit 1.
2. Source libs: `workspace-yml-parser.zsh`, `workspace-graph.zsh`, `workspace-doc-markers.zsh`, `workspace-archetypes.zsh`.
3. `wsyml::load` + `wsyml::validate` + `wsgraph::check_acyclic` on `workspace.yml`. On failure: emit error and exit 2.
4. Build the per-marker content map:
   - `WORKSPACE_PKG_LIST` (meta README): `wsyml::packages` → bullet list `- <name> (<archetype>) — <group>`.
   - `WORKSPACE_LAYERS` (meta ARCH): histogram of archetypes per group → markdown table.
   - `WORKSPACE_GRAPH` (meta ARCH): mermaid `graph TD; A --> B; ...` from deps.
   - `WORKSPACE_PROJECT_RULES` (meta CONTRIBUTING): pre-filled archetype rule reminder + workspace name.
   - Per-package `WORKSPACE_PKG_META`: 6-line key/value block from `wsyml::package_field`.
   - Per-package `WORKSPACE_PKG_PUBLIC_API`: scan `Sources/<name>/**/*.swift` via `grep -E '^public (struct|class|enum|protocol|actor|extension|func|var|let|typealias)'` → bullet list of declarations (one per line, full match line).
   - Per-package `WORKSPACE_PKG_HEADER`: title + archetype + version block.
   - Per-package `WORKSPACE_PKG_DEPS`: two bullet lists (workspace deps + external deps).
5. For each file in scope:
   - `wsmark::lint`. If anomalies AND `--repair` flag: prompt `repair_prompt` → on Y, `wsmark::repair`; on N, count as drift and continue. If anomalies AND no `--repair`: count toward `error_malformed_markers` and skip.
   - For each marker in the file: `wsmark::write` with the canonical content built in step 4.
6. Tally regenerated/drifted/malformed files. Emit appropriate `report_*` / `error_*` locale string.

## Files in scope

- Meta-repo: `README.md`, `ARCHITECTURE.md`, `CONTRIBUTING.md`.
- Per-package (under each package dir): `README.md`, `CLAUDE.md`.

(Per-package `CHANGELOG.md` markers are written by Cluster 2 release tooling — Foundation initialises them empty.)

## --check semantics

Same algorithm, but `wsmark::write` writes to a temp file instead of in-place. After all writes complete, run `diff -u` per file. If any diff non-empty → emit `report_drift_detected`, exit 1. Otherwise → emit `report_no_drift`, exit 0.

## --adopt semantics

Per `--pkg <name>`: read the package's `CLAUDE.md`. If `## Boundary contract` heading exists without surrounding markers, prepend `<!-- WORKSPACE_PKG_BOUNDARY_BEGIN -->` and append `<!-- WORKSPACE_PKG_BOUNDARY_END -->` (interactive prompt with diff). Same logic for `## Public API`. Then run default regen on the package.
