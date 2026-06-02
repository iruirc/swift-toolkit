---
name: feature-estimation
description: "Use when estimating mobile / app feature work — after `feature-landscape` produced work-items. Converts an ideal-day baseline into a calibrated day range using feature-type defaults, PERT for high-risk items, scope-aware additive risk deltas (unknowns, unscoped secondary requirements, parallel API, binary distribution, OS fragmentation), optional project overrides from `CLAUDE-swift-toolkit.md ## EstimationDeltas`, optional AI-assisted range derived per-item, confidence/maturity labels, delivery-calendar conversion, at most one dominant multiplier for unfamiliar tech, and a separate App/Play Store review calendar buffer. Ceremony scales to risk — small familiar features collapse to feature type + baseline + range + confidence. Output is a range anchored to named scenarios, never a point estimate."
---

# Feature Estimation

Estimates fail because they ignore the cost of what nobody wrote down: error states, the App Store review window, the engineer's unfamiliarity with the module, the API contract changing mid-sprint. This skill adds mobile-specific **scope-aware risk deltas** on top of a decomposed baseline, uses PERT only where item-level variance dominates, labels confidence/maturity, and produces a calibrated *range* anchored to named scenarios — never a single number. Ceremony scales to risk: a small, familiar feature collapses to Feature type + Baseline + Range + Confidence, while a cross-platform, deadline-bound migration earns the full artifact. When the project is AI-assisted, it additionally derives a second, AI-assisted range from the same baseline — Low-confidence until the team has calibrated it.

> **Related skills:**
> - `feature-landscape` — produces the work-items list this skill consumes
> - `feature-requirements` — Secondary list and Known Unknowns directly drive the deltas
> - `mobile-ops-checklist` — Applicable ops items either become baseline work items or add concrete days (feature flag wiring, analytics dashboards, on-call runbook)

## When to use

- FEATURE Plan stage after the landscape is drawn; mandatory before Execute
- BUG / REFACTOR Plan stage when the fix/refactor needs a schedule commitment, spans multiple phases, or has a hard release date
- Sprint planning — single-feature commitment to a sprint
- Trade-off discussion with stakeholders ("can this ship by Q3?")
- Direct invocation when the user asks "how long will this take?"

## Inputs

- `Research.md ## Landscape ### Work items` — decomposed list with each item ≤ 2 days
- `Research.md ## Requirements` — Secondary table + Known Unknowns
- Project stack from `CLAUDE-swift-toolkit.md` — for stack-specific deltas (e.g. Android fragmentation only applies if cross-platform)
- Optional project calibration from `CLAUDE-swift-toolkit.md ## EstimationDeltas`
- API readiness state — built / in-parallel / not started
- Engineer familiarity with the module — first time / occasional / fluent
- Release and rollback path — feature flag / kill switch / remote config / hotfix path / binary-only
- Feature type — UI-only / API-driven / SDK integration / persistence or migration / refactor / cross-platform / release-ops-heavy
- Delivery mode — `manual` (default) or `ai-assisted`; from the first non-empty line under `CLAUDE-swift-toolkit.md ## DeliveryMode` or a per-estimate opt-in. Drives the optional AI-assisted range.
- Team calendar assumptions — focus factor or effective capacity, planned external waits, store/release windows
- Hard deadline presence (yes / no)

## The model

```
pert_expected     = (O + 4M + P) / 6              ← central value of a high-variance item
baseline_expected = Σ fixed item days + Σ pert_expected + concrete ops days not already listed
risk_days(s)      = Σ (affected_baseline_expected × risk_delta applied under scenario s)

# the PERT spread feeds the range ends — a risky item is optimistic in best case, pessimistic in worst:
engineering_days(best)  = (Σ fixed + Σ pert_OPTIMISTIC  + ops + risk_days(best))  × dominant_multiplier?
engineering_days(worst) = (Σ fixed + Σ pert_PESSIMISTIC + ops + risk_days(worst)) × dominant_multiplier?

# AI-assisted mode only — derive a second range from the SAME baseline via per-item leverage:
ai_baseline(s)        = Σ (item_human_days(s) ÷ item_leverage)     ← same items (PERT item optimistic in best, pessimistic in worst), divided by their leverage class
ai_engineering(s)     = (ai_baseline(s) + ai_risk_days(s)) × dominant_multiplier?
# ai_risk_days adds the AI verification/rework delta on top of the scenario deltas (see Step 3).

delivery_workdays(s) = engineering_days(s) / focus_factor + external_waits(s)
store_buffer      = +2–7 calendar days            ← reported separately from engineering workdays
```

`engineering_days` and `store_buffer` are different units — working days vs wall-clock calendar days — so they are never added into one engineering figure. Report engineering days as the range, then convert to a separate delivery-calendar view using a stated focus factor and explicit waits.

- **PERT is selective.** Use one ideal-day value for normal items. Use PERT only for high-variance items where the item itself has an optimistic / most-likely / pessimistic spread: new SDKs, migrations, concurrency, auth, offline sync, performance work, unfamiliar frameworks.
- **PERT feeds the range, not just a point.** A PERT item's spread is its whole reason to exist. Use `pert_expected` for the central baseline, but anchor the best-case end with its optimistic value and the worst-case end with its pessimistic value — otherwise the spread is computed and thrown away, and PERT becomes decorative.
- **AI-assisted is derived, not re-estimated.** When AI-assisted mode is on, estimate the human baseline once, then divide each item by its leverage class (Step 2 leverage table) to get the AI baseline. The AI range runs through the same scope-aware deltas plus the AI verification/rework delta. Never run a second independent estimation pass, and never apply a single global "AI multiplier" to the whole feature — leverage is per item, because mechanical CRUD and novel-domain logic in the same feature compress by very different factors.
- **Don't double-count item variance.** A high-variance item handled by PERT already carries its own optimistic↔pessimistic spread. Do not also cite that same item as the reason to raise the Unknown-unknowns delta — Unknown-unknowns covers what you *can't* see, PERT covers the visible spread of a known-risky item.
- **Risk deltas are additive**, not multiplicative. Each delta is a percentage of an affected baseline slice; risk-days are summed once. Risk buffers are slack on the same work — multiplying them double-counts the same uncertainty and inflates an 8-day feature past 25 days. Adding them keeps the adjustment in the realistic 1.5–2.5× band.
- **Risk scope is explicit.** Unknown-unknowns and binary distribution usually apply to the total baseline. API-in-parallel usually applies only to Networking / Repository / Integration items unless the API contract controls the UI/domain shape. Secondary-not-scoped applies to the items that will change if those Secondary requirements land late; use total baseline only when the Pending rows cut across the feature.
- **Binary distribution is a fixed project property, not a scenario knob.** The rollback path (feature flag / kill switch / binary-only) is a fact about the feature, not something that turns out better in the best case and worse in the worst case. Pick one tier (0% / +10% / +20%) and apply the *same* value in both scenarios. The best/worst spread comes from the scenario knobs — unknowns, Secondary, API-in-parallel, PERT spread — not from binary distribution.
- **At most one dominant multiplier** is allowed, applied after the risk-day sum, and only when a single factor genuinely rescales the *whole* effort (e.g. first time on a new framework touches every item). Never stack two multipliers. **When the dominant multiplier is in play, the unfamiliarity it represents IS the unknown — drop the Unknown-unknowns delta to its floor (+30%) or to 0, otherwise you count the same risk twice and re-introduce compounding through the back door.**
- **Store review is a calendar buffer**, kept on its own line — it is wall-clock waiting, not engineering days. Never fold it into the engineering-day figure.

## Estimation depth — scale ceremony to risk

The full artifact below is the *ceiling*, not the floor. A small, familiar, low-risk feature must not carry the same paperwork as a cross-platform migration with a hard deadline. Produce only the sections that earn their place.

**AI-assisted mode (optional, off by default).** When the first non-empty line under `CLAUDE-swift-toolkit.md ## DeliveryMode` is exactly `ai-assisted`, or the estimator opts in for one estimate, the artifact additionally derives an **AI-assisted range** from the same baseline (see *AI-assisted range* below). Any other value, a blank section, or a template placeholder means `manual`. When the mode is off, ignore every AI-assisted instruction in this skill — the estimate is human-only, exactly as the rest of this document describes.

**Minimum viable estimate (always required):**

- `### Feature type` — one line, sets posture
- `### Baseline (per work item)`
- `### Range (engineering days)` — two named scenarios
- `### Confidence`

Everything else is **conditional** — include a section only when its trigger fires:

| Section | Include only when |
|---|---|
| `### Risky item PERT` | at least one high-variance item uses PERT |
| `### Risk deltas (per scenario)` | more than one delta applies; with a single delta, state it inline in the Range instead of a table |
| `### Estimate maturity` | the estimate is `Conditional` (named conditions / unresolved assumptions exist) — a clean estimate is implicitly Committable |
| `### Estimation conditions` | `### Estimate maturity` is `Conditional`; records each condition and whether it blocks Execute |
| `### Assumptions` | the Range depends on any assumption — almost always; omit only for a self-contained estimate with no load-bearing premise |
| `### Delivery calendar (not engineering days)` | a stakeholder needs a date, or a hard deadline / release window is in play |
| `### Store review buffer` | a hard deadline requires a store-submitted build (standalone line, or a row inside the delivery calendar when that section is present) |
| `### Known unknowns blocking final estimate` | any Known Unknown was evaluated — list the open ones, or write `(none)` to show they were checked and none block |
| `### Estimation self-check` | scales to the sections actually present — verify only what you produced |
| `### AI-assisted range` | AI-assisted mode is active; adds the leverage column to `### Baseline` and a derived AI range beside `### Range` |

A UI-only, single-platform, familiar-tech feature with a known rollback path and no open unknown collapses to **Baseline + Range + Confidence + one-line Feature type** — four short sections. The worked example further down is deliberately a *Full* estimate (PERT item, parallel API, scoped Secondary) to show every section; don't mistake it for the minimum.

AI-assisted mode is itself depth-scaled. **Lite**: two one-line ranges — `Human X–Y` and `AI X′–Y′ [Low confidence]` — no leverage table, no AI-delta section. **Full**: the `AI leverage` column on the baseline plus a `### AI-assisted range` section. Off: nothing added.

A minimal (Lite) estimate looks like:

```markdown
## Estimation
### Feature type
UI-only — settings toggle row + persisted flag. Lower API/Secondary risk.

### Baseline (per work item)
| Item | Layer | Ideal days |
|---|---|---:|
| Toggle row + binding | UI | 0.5 |
| Persist + read flag | Repository | 0.5 |
| Unit test | Tests | 0.5 |
| **Baseline total** | | **1.5 days** |

### Range (engineering days)
**Human — Best ~2.0d / Worst ~2.3d** — unknown-unknowns +30%/+50% on 1.5d.
**AI-assisted — Best ~0.5d / Worst ~0.6d [Low confidence, uncalibrated]** — mechanical/pattern items divided by ÷4–5; verification +20% on generated slices.

### Confidence
High — familiar module, flag-gated, no open unknown, no parallel API.
```

### Step 0 — Project calibration overrides

Before estimating, read `CLAUDE-swift-toolkit.md`. If it contains `## EstimationDeltas` with a markdown table, use those project-specific values instead of the defaults below. If the section is absent, blank, or only contains the template placeholder, use the defaults. If a table row is malformed or lacks a reason, ignore that override and note it under Assumptions.

Recommended override format:

```markdown
## EstimationDeltas
| Key | Value | Applies when | Reason |
|---|---:|---|---|
| Unknown unknowns | +20%–35% | Familiar module + stable tests | Team has shipped 5+ similar features within range |
| Secondary not scoped | +30%–50% | Design-system states exist | Error/loading/empty components are reusable |
| Binary distribution risk | +10% | Feature flag + kill switch | Rollback does not require a new binary for most users |
| App / Play Store review | +1–3 calendar days | Enterprise/TestFlight only | No public App Store approval needed |
```

Overrides replace only the named key's default values. They do not remove the requirement to justify each applied delta in the scenario table.

### Step 1 — Feature type defaults

Choose one feature type before estimating. The type sets the default risk posture and prompts; it does not auto-add days without a scoped baseline and justification.

| Feature type | Default posture | Extra checks |
|---|---|---|
| UI-only / copy / small view state | Lower API risk, Secondary still likely | Accessibility, empty/error/loading states, analytics |
| API-driven UI feature | API and Secondary risks often scoped to Networking / Repository / UI slices | Contract freeze, DTO changes, mock-vs-real integration |
| SDK integration | Consider PERT for SDK work; dominant multiplier only if SDK touches most items | Auth, callback model, retries, SDK version constraints |
| Persistence / migration | Consider PERT for migration items | Fixture tests, rollback, data-loss path, offline behavior |
| Refactor / architecture change | Baseline by touched layer; avoid feature-like Secondary unless UX changes | Regression tests, module boundaries, rollout plan |
| Cross-platform feature | Two estimates, one per platform | Platform-specific baselines and fragmentation deltas |
| Release / ops-heavy change | Concrete ops work belongs in baseline | Feature flags, dashboards, runbook, store/release windows |

### Step 2 — Baseline

For each work item from `feature-landscape`, estimate **ideal developer-days**: a single engineer, no interruptions, full knowledge of the codebase, no waiting on anyone. Sum per-item baselines.

Items are already ≤ 2 days (enforced by `feature-landscape` Step 4). If any item is larger, return to the landscape and decompose further — don't estimate at the wrong granularity.

For normal work items, use one ideal-day value. For a high-variance item, use PERT:

```
PERT days = (optimistic + 4 × most_likely + pessimistic) / 6
```

Use PERT for specific risky items, not for every row. If several rows need pessimistic estimates, the landscape is probably under-decomposed or the estimate is too immature.

If planning-time ops review or the release plan reveals applicable ops work that is not already in the work-items list, add it as concrete baseline work, not as a risk delta. Typical examples: feature flag wiring (0.5d), analytics dashboard or alert (0.5–1.0d), kill-switch verification (0.5d), on-call / rollback runbook (0.5d). Use local team calibration if available.

**AI leverage classes (AI-assisted mode only).** Tag each baseline item with one class; its divisor turns the human ideal-days into AI-assisted days. Leverage is a property of the *nature of the work*, not the layer — a Repository row can be mechanical CRUD (high leverage) or a tricky cache-merge (low). The bands are wide on purpose; the AI range they produce is Low-confidence until calibrated (Step 6).

| Class | Typical work | Default divisor (guidance) |
|---|---|---:|
| `mechanical` | CRUD, DTO mapping, boilerplate, scaffolding, config | ÷3–10 |
| `pattern-test` | tests / UI built to an established pattern | ÷3–5 |
| `glue` | wiring, integration plumbing | ÷1.5–2 |
| `novel-domain` | business logic, tricky algorithms, concurrency, migration correctness | ÷1–1.3 |
| `spec-bound` | work where the spec or the review *is* the cost | ÷1 (no leverage) |

Project overrides live in `CLAUDE-swift-toolkit.md ## AILeverage`, using the same table format and discipline as `## EstimationDeltas`: malformed or placeholder rows are ignored and fall back to these defaults, and an override never removes the requirement to justify the class chosen for each item.

### Step 3 — Apply risk deltas

For every applicable delta below, choose an **affected baseline** and calculate `risk_days = affected_baseline × delta`. Sum the risk days into the scenario result. Record each delta used with its scope and justification.

| Risk delta | Value | When applies |
|---|---|---|
| Unknown unknowns | **+30%–50%** | Always (the one delta never skipped). Familiarity sets where the band sits — anchor near +30% for well-known territory, near +50% for greenfield. Unlike binary distribution, this delta *may* vary across scenarios: best case = fewer hidden surprises (lower end), worst case = more (upper end). |
| Secondary requirements not yet scoped | **+40%–70%** | When `feature-requirements ### Secondary` still has Pending rows |
| API in parallel | **+30%–40%** | API being built same sprint — contract may shift |
| Binary distribution risk | **0% / +10% / +20%** | 0% for SPM/CLI/no user-facing binary. +10% when feature flag / kill switch / remote rollback covers most failures. +20% for user-facing iOS/macOS binary with no instant rollback. |
| OS / device fragmentation | **+20%–30%** | Android only — Custom UI, Camera, Media. iOS-only project: skip. |
| AI verification / rework | **+15%–40%** (AI-assisted mode only) | Scoped to AI-generated slices — cost of reviewing output, catching plausible-but-wrong code, prompt iteration. Higher share AI-generated / more novel → upper end. |

Under AI-assisted mode, the Unknown-unknowns delta may sit *higher* on a novel domain — AI can produce plausible-but-wrong code that hides risk — and *lower* on well-trodden ground. Pick the band end accordingly; this composes with the rule that Unknown-unknowns is a scenario knob.

**Dominant multiplier (at most one, applied after the risk-day sum):**

| Multiplier | Value | When applies |
|---|---|---|
| New tech / unfamiliar module | **×1.5–2.0** | First time touching this area; new SDK; new framework that touches most work items |

*Worked example with a dominant multiplier:* baseline 6.0 days, first time on a new framework (×1.8). Because the multiplier already represents the unfamiliarity, Unknown-unknowns drops to its +30% floor and binary-distribution stays at +20%, both scoped to the full baseline → risk days = `6.0 × 0.30 + 6.0 × 0.20 = 3.0`. Result: `(6.0 + 3.0) × 1.8 = 16.2 days`. Not `6.0 × (1 + 0.50 + 0.50_for_newtech) × 1.8` — that would count the new-framework risk in both the delta and the multiplier.

**Calendar buffer (separate line, not engineering days):**

| Buffer | Value | When applies |
|---|---|---|
| App / Play Store review | **+2–7 calendar days** | Any hard deadline that requires a store-submitted build |

**Rules:**
- Deltas **add as risk days**. App Store buffer is reported on its own line as calendar time.
- Always name the affected baseline for each delta. Do not apply API or Secondary deltas to the whole feature when the risk only touches one layer.
- Don't double-count: if Secondary is fully scoped (no Pending rows), don't apply the Secondary delta — those days are already in the baseline.
- Don't push Unknown Unknowns above +50% — beyond that you're guessing, not buffering. Decompose the landscape further instead.
- Use the dominant multiplier sparingly: only when one factor rescales the whole effort. Two multipliers is a red flag — fold the weaker one back into a delta.
- Cross-platform = two estimates, not one. Each platform gets its own baseline + deltas, then the totals sum. Never `× 0.5`.

### Step 4 — Known unknowns gate

List every Known Unknown from `feature-requirements ### Known unknowns`. For each:

- If unresolved at estimation time → the estimate is **conditional** ("9–12 days *assuming* the API contract is finalized this week")
- **Load-bearing-unknown rule** (the canonical 30% threshold — defined here, referenced everywhere else): if a Known Unknown could swing the estimate by **more than 30%**, add a required spike (usually 0.5–1.0d, or locally calibrated), return to `feature-requirements`, and do not finalize the estimate until the spike resolves or narrows the unknown. Maturity and the Plan-stage gate cite this rule by name; change the threshold here only.

### Step 5 — Communicate as a scenario-anchored range

Output is **always** a range, never a point. **Each end of the range is a named scenario**, not a min/max product of the deltas. Pick which deltas apply under each scenario and which assumptions hold.

- **Low end** = optimistic scenario: load-bearing assumptions hold (API frozen, Secondary already scoped), so fewer deltas apply and applicable ones sit at their low value.
- **High end** = pessimistic scenario: assumptions break (build against a mock, Secondary discovered late), more deltas apply at their high value.

State the assumptions that define each scenario. The range is the spread between two coherent worlds — not the arithmetic min and max of every knob simultaneously (those extremes are jointly near-impossible and produce a falsely wide band).

Example:

> "**10.7 days** — *best case*: API contract finalized this week, existing `CartRepository` reused, Secondary mockups already delivered, feature flag and kill switch available. Cache item takes its PERT-optimistic 0.5d (baseline 7.5d), Unknown-unknowns apply to the 8.0d expected baseline (+30% = 2.4d), binary-distribution applies at the mitigated +10% level (= 0.8d).
> **16.6 days** — *worst case*: building against a mock, contract deltas surface at integration, Secondary left for last. Cache item takes its PERT-pessimistic 1.5d (baseline 8.5d), Unknowns apply to the 8.0d expected baseline (+50% = 4.0d), Secondary applies to the 3.0d UI/state/test slice (+70% = 2.1d), API-parallel applies to the 3.0d networking/repository slice (+40% = 1.2d). Binary distribution stays at its fixed +10% (= 0.8d) — the flag/kill-switch path doesn't change between scenarios.
> **+2–7 calendar days** App Store review buffer on top, when a hard deadline applies — this is wall-clock waiting, not engineering days."

If an assumption breaks, the estimate moves toward the high end — and that's expected.

### Step 6 — Confidence and estimate maturity

These are **two independent axes**, not two names for the same thing. Confidence measures *how tight and well-evidenced the number is*; maturity measures *whether it's safe to act on yet*. Keep them separate — a precise estimate can still be blocked, and a fuzzy one can still be safe to start.

**Confidence — width and evidence of the range** (always stated):

| Label | Meaning |
|---|---|
| High | Narrow best↔worst spread, backed by evidence: similar feature shipped, work-items decomposed, stack familiar |
| Medium | Moderate spread; some inputs rest on judgement rather than evidence |
| Low | Wide spread, unfamiliar tech, or thin evidence — the number is a guess with error bars |

**AI-assisted ranges start at Confidence: Low.** Until the team's retrospective has calibrated the leverage classes (suggested: ≥3–5 shipped AI-assisted features landing in range), label any AI-assisted range `Low (uncalibrated)` regardless of how tight it looks. The wide leverage bands are guidance, not measured velocity. After calibration it rises on the normal confidence scale.

**Maturity — readiness to enter Execute** (stated only when not plainly Committable):

| Label | Meaning |
|---|---|
| Draft | Missing landscape, baseline, or other load-bearing input — not ready |
| Conditional | Rests on named conditions (e.g. a contract freeze) that are not yet accepted, **or** an open Known Unknown still trips the load-bearing-unknown rule (Step 4) |
| Committable | No blocking conditions and no load-bearing unknown — safe to plan delivery against |

When maturity is `Conditional`, add `### Estimation conditions`:

```markdown
### Estimation conditions
| Condition | Owner | Status | Evidence / next action |
|---|---|---|---|
| Backend contract frozen by end of week 1 | Backend | pending_user | Ask user before Execute |
```

Allowed statuses:

- `pending_user` — blocks Execute until the user accepts, defers, or resolves it.
- `accepted` — user explicitly accepts this assumption; keep it visible for Review/Done.
- `deferred` — condition is intentionally moved out of scope or to a later task.
- `resolved` — evidence is available in an artifact, commit, ticket, or user response.

The two axes are orthogonal — all four corners occur:

- **High + Committable** — a familiar, fully-scoped feature. Start now.
- **High + Conditional** — numbers are tight, but Execute waits on the backend accepting a contract.
- **Low + Committable** — wide range from unfamiliar tech, yet nothing *blocks* starting; you commit to the wide range knowingly.
- **Low + Draft** — wide *and* missing inputs. Go back to landscape/requirements.

So state confidence to tell the reader how much to trust the width, and maturity to tell the workflow whether it may proceed. Don't collapse them: "Low confidence" is not a reason to block, and "Conditional" is not a statement about precision.

### Step 7 — Delivery calendar conversion

Engineering days are not a promise of calendar dates. If stakeholders need delivery timing, convert the engineering range into a separate delivery-calendar view:

- State the focus factor or effective capacity (for example, `0.6` when one engineer has 60% focused capacity after meetings/support).
- Add explicit external waits separately: backend/design handoff, review boards, release train cutoffs, store review.
- Do not hide the conversion inside the engineering range.

### Step 8 — Estimation self-check

This is a verification pass, not a formality. Tick `[x]` only after you have actually checked the item against the artifact; mark `n/a` (with the reason) where it doesn't apply; mark `[ ]` and fix the plan where it fails. A self-check that is uniformly `[x]` on every feature is a sign it was rubber-stamped, not run.

Verify:

- Every affected-baseline slice traces to named baseline rows.
- Risk-days arithmetic matches the scenario table.
- Each PERT item's optimistic value feeds the best-case end and its pessimistic value the worst-case end — the spread is not discarded.
- No PERT item is also used as the justification for raising the Unknown-unknowns delta.
- Binary distribution uses one fixed tier in both scenarios — it is not varied per scenario.
- App/Play Store review is not included in engineering days.
- Delivery calendar is separated from the engineering range.
- Secondary delta is absent when Secondary is fully scoped.
- The dominant multiplier, if present, does not double-count unfamiliarity already covered by Unknown-unknowns.
- In AI-assisted mode, the AI range is derived from the human baseline per item, not re-estimated independently or produced with one global multiplier.
- In AI-assisted Full mode, `### Baseline` includes the `AI leverage` column and `### AI-assisted range` re-sums the AI baseline and AI risk deltas from those rows.
- Every uncalibrated AI-assisted range is labelled `Low (uncalibrated)` and remains informational.
- Known Unknowns that trip the load-bearing-unknown rule (Step 4) have a required spike or resolution.
- Confidence is stated; maturity is stated whenever it is not plainly Committable.
- Conditional maturity includes `### Estimation conditions`; any `pending_user` row is treated as an Execute blocker.

## Output artifact

Write into the active task's `Plan.md` under heading `## Estimation`. The example below is a **Full conditional estimate**: it deliberately includes `pending_user` conditions and therefore does **not** pass the Execute gate until those rows are accepted, deferred, or resolved.

```markdown
## Estimation

### Feature type
API-driven UI feature. Default posture: API and Secondary risks are likely scoped to Networking / Repository / UI slices; store/release risk depends on rollback path.

### Baseline (per work item)
| Item | Layer | Estimate method | AI leverage | Ideal days |
|---|---|---|---|---:|
| Define CartItem / Order / PaymentStatus | Domain | Fixed | novel-domain ÷1.2 | 0.5 |
| `CartRepository` add/remove/clear | Repository | Fixed | mechanical ÷5 | 1.0 |
| Cart API client + DTO mapping | Networking | Fixed | mechanical ÷6 | 1.0 |
| Local cache (Core Data) | Repository | PERT 0.5 / 1.0 / 1.5 | novel-domain ÷1.2 | 1.0 |
| `CartViewModel` state transitions | State | Fixed | glue ÷1.8 | 1.0 |
| Cart screen + cell UI | UI | Fixed | pattern-test ÷4 | 1.0 |
| Unit tests (ViewModel + repository) | Tests | Fixed | pattern-test ÷4 | 1.0 |
| Feature flag wiring + kill-switch verification | Release readiness | Fixed | glue ÷1.8 | 1.0 |
| Analytics events (add / remove / checkout) | Release readiness | Fixed | mechanical ÷5 | 0.5 |
| **Baseline total** | | | | **8.0 days** |

### Risky item PERT
| Item | Optimistic | Most likely | Pessimistic | PERT days | Why PERT applies |
|---|---:|---:|---:|---:|---|
| Local cache (Core Data) | 0.5 | 1.0 | 1.5 | 1.0 | Cache model shape may change with backend contract |

> **Affected-baseline slices** below are summed from the Layer column above:
> networking/repository slice = Repository 1.0 + Networking 1.0 + Repository (cache) 1.0 = **3.0d**;
> UI/state/tests slice = State 1.0 + UI 1.0 + Tests 1.0 = **3.0d**.

### Risk deltas (per scenario)
> Columns are the two **scenarios**, not the low/high values of each delta. A delta that
> doesn't apply under a scenario shows `—`. Don't read these as "all knobs at minimum" vs
> "all knobs at maximum" — that's the min/max-product fallacy Step 5 warns against.

| Risk delta | Affected baseline | Best-case scenario | Worst-case scenario | Justification |
|---|---:|---:|---:|---|
| Unknown unknowns | 8.0d total | +30% = 2.4d | +50% = 4.0d | Mid-familiarity territory |
| Secondary not scoped | 3.0d UI/state/tests | — (scoped) | +70% = 2.1d | Designer mockups: delivered in best case, late in worst |
| API in parallel | 3.0d networking/repository | — (frozen) | +40% = 1.2d | Best: contract frozen wk1. Worst: built against mock |
| Binary distribution | 8.0d total | +10% = 0.8d | +10% = 0.8d | Fixed: feature flag + kill switch exist — same tier in both scenarios |
| **Σ risk days** | | **3.2d** | **8.1d** | |
| Dominant multiplier | | none | none | No new-framework work this feature |

### Range (engineering days)
PERT spread feeds the ends: the cache item is optimistic (0.5) in best case, pessimistic (1.5) in worst, so the scenario baseline shifts ±0.5 from the 8.0 expected total. Risk-days stay scoped to the 8.0 expected baseline.

**Best case:  baseline 7.5 (cache @ 0.5) + risk 3.2 = 10.7 days**
**Worst case: baseline 8.5 (cache @ 1.5) + risk 8.1 = 16.6 days**

### AI-assisted range
Derived from the same baseline: each item divided by its leverage class → AI baseline ≈ 3.3d expected. The PERT cache item feeds the ends just as on the human side — AI baseline ≈ 2.9d in best case (cache @ 0.5 ÷ 1.2) and ≈ 3.7d in worst (cache @ 1.5 ÷ 1.2). Then the scenario deltas (Unknown-unknowns +30%/+50%, binary fixed +10%, Secondary/API on their AI slices in the worst case) plus AI verification/rework +20% on the AI-generated slices.

**Best case ≈ 4.5d / Worst case ≈ 7.8d — Confidence: Low (uncalibrated).**

This range is informational until the team's retrospective calibrates the leverage classes. The human `### Range` above and this AI range are both reported; which one becomes the delivery commitment is a planning decision, not this skill's.

### Confidence
Medium — work items are decomposed and the rollback path is known, but API/design timing still shapes the scenario range.

### Estimate maturity
Conditional — see `### Estimation conditions` for the blocking conditions; no Known Unknown trips the load-bearing-unknown rule.

### Estimation conditions
| Condition | Owner | Status | Evidence / next action |
|---|---|---|---|
| Backend contract frozen by end of week 1 | Backend | pending_user | Ask user before Execute; if accepted, keep the 10.7–16.6d range |
| Designer secondary states accepted as scenario assumptions | Design/Product | pending_user | Ask user before Execute; if rejected, re-scope Secondary and re-estimate |

### Delivery calendar (not engineering days)
| Component | Best case | Worst case | Notes |
|---|---:|---:|---|
| Engineering days | 10.7d | 16.6d | From `### Range` above |
| Focus factor | / 0.6 | / 0.6 | One engineer at 60% focused capacity |
| External waits | +0 workdays | +2 workdays | Worst case assumes backend/design wait |
| Delivery workdays before store | ~18 workdays | ~30 workdays | Engineering / focus + explicit waits; still working days — convert to calendar via the team's week before quoting a date |
| Store review | +2–7 calendar days | +2–7 calendar days | Separate wall-clock buffer, not engineering |

### Assumptions
1. **Best case** holds when: designer error/loading/empty mockups already delivered, backend contract frozen by end of week 1, existing `ProductRepository` reused as-is.
2. **Worst case** assumes: building against a mock, contract deltas at integration, Secondary scoped late.
3. No new platform support (iOS-only).

### Known unknowns blocking final estimate
(none — remaining assumptions are tracked above and each expected swing is ≤30%)

### Estimation self-check
- [x] Affected-baseline slices trace to baseline rows.
- [x] Risk-days arithmetic matches the scenario table (re-summed worst case to 8.1d after the binary fix below).
- [x] Cache PERT spread feeds the range: 0.5 in best case, 1.5 in worst; not discarded.
- [x] PERT cache item is not reused to justify the Unknown-unknowns delta.
- [x] Binary distribution fixed at +10% in both scenarios — caught and corrected an earlier draft that varied it +10%/+20% per scenario.
- [x] App/Play Store review is not included in engineering days.
- [x] Delivery calendar is separate from engineering range.
- [x] Secondary delta is skipped in best case because Secondary is scoped.
- n/a Dominant multiplier — no new-framework work this feature, so the double-count guard doesn't apply.
- [x] No Known Unknown trips the load-bearing-unknown rule without a spike.
- [x] Confidence stated (Medium); maturity stated because this estimate is Conditional.
- [x] Estimation conditions record two `pending_user` rows; Execute must return `ask_user` until they are accepted, deferred, or resolved.
```

### Plan-stage gate

Before entering Execute, `Plan.md` MUST contain the **minimum viable estimate** plus every section whose trigger fired (see *Estimation depth* above):

- `## Estimation` with `### Feature type` (one line), `### Baseline (per work item)` including concrete ops work, `### Range (engineering days)` with named best/worst scenarios, and `### Confidence` — always.
- `### Assumptions` whenever the Range depends on any assumption (almost always).
- Conditional sections (`### Risky item PERT`, `### Risk deltas (per scenario)`, `### Estimate maturity`, `### Estimation conditions`, `### Delivery calendar`, `### Store review buffer`, `### Known unknowns blocking final estimate`, `### Estimation self-check`) only when their trigger fired. A missing conditional section whose trigger *did* fire makes the Plan incomplete; a missing one whose trigger did not fire is correct, not a gap. The store-review buffer counts as present when it appears as a row inside `### Delivery calendar` — it does not also need a standalone `### Store review buffer` section.

Gate by maturity (an absent `### Estimate maturity` section means a clean estimate — treat as Committable):

- **Draft** → Plan is not complete. Return control with `ask_user`; never enter Execute.
- **Conditional** → do NOT enter Execute silently. `### Estimation conditions` must exist. If any condition is `pending_user`, return control with `ask_user`, listing each pending condition for the user to accept, defer, or resolve. On resume, the architect records the user's response into the row's `Status` (and `Evidence / next action`) — never silently; a `pending_user` row left untouched still blocks. Execute may begin only after every condition is recorded as `accepted`, `deferred`, or `resolved`.
- **Committable (or no maturity section)** → gate passes on this axis.

Independently of maturity, the Plan is also incomplete — return `ask_user` — if `## Estimation` is missing/malformed, a required section above is absent, or a Known Unknown trips the load-bearing-unknown rule (Step 4) without a required spike/resolution.

**Idempotency:** if `## Estimation` already exists in `Plan.md`, prompt the user before overwriting. Re-estimation is normal mid-feature — keep the previous version under `### Estimation history` with a date.

## Anti-patterns to avoid

- **Happy-path only estimate.** Ignoring Secondary turns a 10-day feature into a 20-day surprise.
- **"It's just a UI change."** UI almost always touches state, tests, analytics, and edge cases. The Secondary delta exists for exactly this.
- **Multiplying risk buffers.** Five compounding multipliers turn an 8-day feature into 26+ days of fiction. Risk deltas are slack on the same work — they add, they don't multiply.
- **Globalizing scoped risk.** Applying API-in-parallel or Secondary-not-scoped to the whole baseline when only Networking or UI changes creates inflated ranges and hides the real risk owner.
- **Min/max product as the range.** "All knobs at minimum" and "all knobs at maximum" are jointly near-impossible. Anchor each end to a coherent scenario instead.
- **Shared estimate across platforms.** iOS and Android are not "the same work × 2 people." Each is its own decomposition, baseline, and delta set.
- **Point estimate without decomposition.** "Probably 2 weeks" with no work-item list is fiction. Always decompose first via `feature-landscape`.
- **Velocity-based without breakdown.** Story points are a team-private calibration on top of decomposition — not a replacement for it.
- **Delta without justification.** Each delta must be tied to a concrete observation. "Felt risky" is not a justification.
- **Communicating a single number to stakeholders.** Always give a range with scenarios. If forced into a single number, give the high end.
- **Folding store review into engineering days.** Review windows are calendar time, not engineering time. Always surface them on their own line.
- **Treating engineering days as calendar promise.** Convert through focus factor and explicit waits in `### Delivery calendar`; don't imply 12 engineering days means 12 calendar days.
- **Using PERT everywhere.** PERT is for specific high-variance rows. Using it for every row creates noise and hides decomposition problems.
- **Skipping the spike for load-bearing unknowns.** A Known Unknown that trips the load-bearing-unknown rule (Step 4) must get a spike or resolution before final estimation.
- **Omitting confidence or maturity.** A range without quality labels looks more precise than it is. (Maturity is itself conditional — a clean estimate is implicitly Committable; don't add the label just to have it.)
- **Conditional without durable conditions.** If maturity is `Conditional`, the conditions must live in `### Estimation conditions` with statuses. Free-form prose is not enough after resume.
- **Full ceremony for a trivial estimate.** A 1.5-day, familiar, flag-gated UI tweak does not need PERT, a delivery calendar, a maturity label, and the full self-check. Scale to the *Estimation depth* table — Feature type + Baseline + Range + Confidence is the floor. Filling every section by reflex produces rubber-stamped paperwork, not a better estimate.
- **A single global "AI multiplier."** Dividing the whole feature by one AI factor repeats the global-multiplier mistake. Leverage is per item — mechanical and novel-domain work in the same feature compress by very different factors.
- **Trusting an uncalibrated AI divisor as committable.** The default leverage bands are wide guidance, not measured team velocity. An AI-assisted range stays Low-confidence and informational until the retrospective has calibrated it.

## Calibration over time

Static deltas are a starting point, not a prescription. After each shipped feature, compare *estimated range* to *actual engineering days*. Patterns that emerge:

- Deltas consistently too low → the team is under-decomposing the landscape; push for finer work items.
- Deltas consistently too high → the team has built up tooling/library that reduces the Secondary cost; lower the Secondary delta for this codebase.

Project-specific overrides live in `CLAUDE-swift-toolkit.md ## EstimationDeltas` using the table format from Step 0. Keep overrides sparse: only encode repeatable evidence from multiple finished features, not one-off surprises.

Under AI-assisted mode, the retrospective also compares the AI-assisted estimate against actual AI-assisted engineering days **per leverage class**, and narrows the class divisors over time via `CLAUDE-swift-toolkit.md ## AILeverage`. Until enough finished AI-assisted features exist to do this, keep AI-assisted ranges at Low confidence.

At Done / Review time, MUST add an estimate retrospective when an estimate exists. Actual engineering days are active implementation/review/test days, not wall-clock waiting:

```markdown
## Estimate retrospective
| Estimated range | Actual engineering days | In range? | Variance reason | Calibration action |
|---:|---:|---|---|---|
| 10.7–16.6d | 18.0d | Over (+8%) | Backend changed response shape after integration | Keep API-in-parallel high end at +40% |
```

If actual effort is unknown, write `unknown` and explain what signal is missing. Do not invent actual days from commit count alone.

## Platform-specific notes

- **SPM library / CLI** — Skip App Store buffer; skip OS fragmentation; binary-distribution delta is 0% unless the library is shipped as a binary artifact (e.g. xcframework).
- **macOS app distributed via Mac App Store** — App Store buffer applies; via Developer ID / direct distribution → skip the buffer but add notarization time (~1 hour, not days).
- **iOS app** — Unknown-unknowns and binary-distribution are usually in scope; choose binary risk from the rollback path (0% / +10% / +20%). Skip OS fragmentation unless the project is cross-platform Android.

## What this skill does NOT do

- Does NOT produce a single number — only ranges.
- Does NOT promise calendar dates from engineering days alone — delivery-calendar conversion is separate and must state focus factor, external waits, and store/release buffers.
- Does NOT decide priority or scope — that's the product / planning conversation.
- Does NOT estimate features without a landscape — return to `feature-landscape` first if no work-items list exists.
- Does NOT fully model per-item uncertainty — PERT covers selected high-variance rows, but risk deltas are still a coarse planning tool. When per-item variance dominates many rows, decompose finer instead of leaning on one global delta.
- Does NOT decide which range becomes the delivery commitment — in AI-assisted mode both the human and the AI-assisted range are reported, and choosing the promised number is the planning conversation's job.
