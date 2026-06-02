---
name: feature-estimation
description: "Use when estimating mobile / app feature work — after `feature-landscape` produced work-items. Converts an ideal-day baseline into a calibrated day range using feature-type defaults, PERT for high-risk items, scope-aware additive risk deltas (unknowns, unscoped secondary requirements, parallel API, binary distribution, OS fragmentation), optional project overrides from `CLAUDE-swift-toolkit.md ## EstimationDeltas`, confidence/maturity labels, delivery-calendar conversion, at most one dominant multiplier for unfamiliar tech, and a separate App/Play Store review calendar buffer. Output is a range anchored to named scenarios, never a point estimate."
---

# Feature Estimation

Estimates fail because they ignore the cost of what nobody wrote down: error states, the App Store review window, the engineer's unfamiliarity with the module, the API contract changing mid-sprint. This skill adds mobile-specific **scope-aware risk deltas** on top of a decomposed baseline, uses PERT only where item-level variance dominates, labels confidence/maturity, and produces a calibrated *range* anchored to named scenarios — never a single number.

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
- Team calendar assumptions — focus factor or effective capacity, planned external waits, store/release windows
- Hard deadline presence (yes / no)

## The model

```
pert_expected     = (O + 4M + P) / 6              ← central value of a high-variance item
baseline_expected = Σ fixed item days + Σ pert_expected + concrete ops days not already listed
risk_days(s)      = Σ (affected_baseline_expected × risk_delta applied under scenario s)

# the PERT spread feeds the range ends — a risky item is optimistic in best case, pessimistic in worst:
engineering_best  = (Σ fixed + Σ pert_OPTIMISTIC  + ops + risk_days(best))  × dominant_multiplier?
engineering_worst = (Σ fixed + Σ pert_PESSIMISTIC + ops + risk_days(worst)) × dominant_multiplier?

delivery_workdays = engineering_days / focus_factor + external_waits
store_buffer      = +2–7 calendar days            ← reported separately from engineering workdays
```

`engineering_days` and `store_buffer` are different units — working days vs wall-clock calendar days — so they are never added into one engineering figure. Report engineering days as the range, then convert to a separate delivery-calendar view using a stated focus factor and explicit waits.

- **PERT is selective.** Use one ideal-day value for normal items. Use PERT only for high-variance items where the item itself has an optimistic / most-likely / pessimistic spread: new SDKs, migrations, concurrency, auth, offline sync, performance work, unfamiliar frameworks.
- **PERT feeds the range, not just a point.** A PERT item's spread is its whole reason to exist. Use `pert_expected` for the central baseline, but anchor the best-case end with its optimistic value and the worst-case end with its pessimistic value — otherwise the spread is computed and thrown away, and PERT becomes decorative.
- **Don't double-count item variance.** A high-variance item handled by PERT already carries its own optimistic↔pessimistic spread. Do not also cite that same item as the reason to raise the Unknown-unknowns delta — Unknown-unknowns covers what you *can't* see, PERT covers the visible spread of a known-risky item.
- **Risk deltas are additive**, not multiplicative. Each delta is a percentage of an affected baseline slice; risk-days are summed once. Risk buffers are slack on the same work — multiplying them double-counts the same uncertainty and inflates an 8-day feature past 25 days. Adding them keeps the adjustment in the realistic 1.5–2.5× band.
- **Risk scope is explicit.** Unknown-unknowns and binary distribution usually apply to the total baseline. API-in-parallel usually applies only to Networking / Repository / Integration items unless the API contract controls the UI/domain shape. Secondary-not-scoped applies to the items that will change if those Secondary requirements land late; use total baseline only when the Pending rows cut across the feature.
- **At most one dominant multiplier** is allowed, applied after the risk-day sum, and only when a single factor genuinely rescales the *whole* effort (e.g. first time on a new framework touches every item). Never stack two multipliers. **When the dominant multiplier is in play, the unfamiliarity it represents IS the unknown — drop the Unknown-unknowns delta to its floor (+30%) or to 0, otherwise you count the same risk twice and re-introduce compounding through the back door.**
- **Store review is a calendar buffer**, kept on its own line — it is wall-clock waiting, not engineering days. Never fold it into the engineering-day figure.

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

### Step 3 — Apply risk deltas

For every applicable delta below, choose an **affected baseline** and calculate `risk_days = affected_baseline × delta`. Sum the risk days into the scenario result. Record each delta used with its scope and justification.

| Risk delta | Value | When applies |
|---|---|---|
| Unknown unknowns | **+30%–50%** | Always. +30% for well-known territory, +50% for greenfield. |
| Secondary requirements not yet scoped | **+40%–70%** | When `feature-requirements ### Secondary` still has Pending rows |
| API in parallel | **+30%–40%** | API being built same sprint — contract may shift |
| Binary distribution risk | **0% / +10% / +20%** | 0% for SPM/CLI/no user-facing binary. +10% when feature flag / kill switch / remote rollback covers most failures. +20% for user-facing iOS/macOS binary with no instant rollback. |
| OS / device fragmentation | **+20%–30%** | Android only — Custom UI, Camera, Media. iOS-only project: skip. |

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
- If a Known Unknown could swing the estimate >30% → add a required spike (usually 0.5–1.0d, or locally calibrated), return to `feature-requirements`, and do not finalize the estimate until the spike resolves or narrows the unknown

### Step 5 — Communicate as a scenario-anchored range

Output is **always** a range, never a point. **Each end of the range is a named scenario**, not a min/max product of the deltas. Pick which deltas apply under each scenario and which assumptions hold.

- **Low end** = optimistic scenario: load-bearing assumptions hold (API frozen, Secondary already scoped), so fewer deltas apply and applicable ones sit at their low value.
- **High end** = pessimistic scenario: assumptions break (build against a mock, Secondary discovered late), more deltas apply at their high value.

State the assumptions that define each scenario. The range is the spread between two coherent worlds — not the arithmetic min and max of every knob simultaneously (those extremes are jointly near-impossible and produce a falsely wide band).

Example:

> "**10.7 days** — *best case*: API contract finalized this week, existing `CartRepository` reused, Secondary mockups already delivered, feature flag and kill switch available. Cache item takes its PERT-optimistic 0.5d (baseline 7.5d), Unknown-unknowns apply to the 8.0d expected baseline (+30% = 2.4d), binary-distribution applies at the mitigated +10% level (= 0.8d).
> **17.4 days** — *worst case*: building against a mock, contract deltas surface at integration, Secondary left for last. Cache item takes its PERT-pessimistic 1.5d (baseline 8.5d), Unknowns apply to the 8.0d expected baseline (+50% = 4.0d), Secondary applies to the 3.0d UI/state/test slice (+70% = 2.1d), API-parallel applies to the 3.0d networking/repository slice (+40% = 1.2d), binary applies at +20% (= 1.6d).
> **+2–7 calendar days** App Store review buffer on top, when a hard deadline applies — this is wall-clock waiting, not engineering days."

If an assumption breaks, the estimate moves toward the high end — and that's expected.

### Step 6 — Confidence and estimate maturity

Label the estimate with both confidence and maturity:

| Label | Meaning |
|---|---|
| Confidence: High | Similar feature shipped before, work-items are decomposed, API/design/release path are stable |
| Confidence: Medium | Some assumptions remain, but no unresolved unknown can swing the estimate >30% |
| Confidence: Low | Multiple assumptions remain, unfamiliar tech, or evidence is thin |

| Maturity | Execute gate |
|---|---|
| Draft | Not ready for Execute; missing landscape, baseline, or load-bearing inputs |
| Conditional | Execute may proceed only if the named conditions are accepted, deferred, or resolved and no unresolved Known Unknown can swing >30% |
| Committable | Inputs are stable enough to use the range for delivery planning |

### Step 7 — Delivery calendar conversion

Engineering days are not a promise of calendar dates. If stakeholders need delivery timing, convert the engineering range into a separate delivery-calendar view:

- State the focus factor or effective capacity (for example, `0.6` when one engineer has 60% focused capacity after meetings/support).
- Add explicit external waits separately: backend/design handoff, review boards, release train cutoffs, store review.
- Do not hide the conversion inside the engineering range.

### Step 8 — Estimation self-check

Before handing off the plan, verify:

- Every affected-baseline slice traces to named baseline rows.
- Risk-days arithmetic matches the scenario table.
- Each PERT item's optimistic value feeds the best-case end and its pessimistic value the worst-case end — the spread is not discarded.
- No PERT item is also used as the justification for raising the Unknown-unknowns delta.
- App/Play Store review is not included in engineering days.
- Delivery calendar is separated from the engineering range.
- Secondary delta is absent when Secondary is fully scoped.
- The dominant multiplier, if present, does not double-count unfamiliarity already covered by Unknown-unknowns.
- Known Unknowns above 30% have a required spike or resolution.
- Confidence and maturity labels are present.

## Output artifact

Write into the active task's `Plan.md` under heading `## Estimation`. Structure:

```markdown
## Estimation

### Feature type
API-driven UI feature. Default posture: API and Secondary risks are likely scoped to Networking / Repository / UI slices; store/release risk depends on rollback path.

### Baseline (per work item)
| Item | Layer | Estimate method | Ideal days |
|---|---|---|---:|
| Define CartItem / Order / PaymentStatus | Domain | Fixed | 0.5 |
| `CartRepository` add/remove/clear | Repository | Fixed | 1.0 |
| Cart API client + DTO mapping | Networking | Fixed | 1.0 |
| Local cache (Core Data) | Repository | PERT 0.5 / 1.0 / 1.5 | 1.0 |
| `CartViewModel` state transitions | State | Fixed | 1.0 |
| Cart screen + cell UI | UI | Fixed | 1.0 |
| Unit tests (ViewModel + repository) | Tests | Fixed | 1.0 |
| Feature flag wiring + kill-switch verification | Release readiness | Fixed | 1.0 |
| Analytics events (add / remove / checkout) | Release readiness | Fixed | 0.5 |
| **Baseline total** | | | **8.0 days** |

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
| Binary distribution | 8.0d total | +10% = 0.8d | +20% = 1.6d | Best: flag + kill switch. Worst: binary-only rollback |
| **Σ risk days** | | **3.2d** | **8.9d** | |
| Dominant multiplier | | none | none | No new-framework work this feature |

### Range (engineering days)
PERT spread feeds the ends: the cache item is optimistic (0.5) in best case, pessimistic (1.5) in worst, so the scenario baseline shifts ±0.5 from the 8.0 expected total. Risk-days stay scoped to the 8.0 expected baseline.

**Best case:  baseline 7.5 (cache @ 0.5) + risk 3.2 = 10.7 days**
**Worst case: baseline 8.5 (cache @ 1.5) + risk 8.9 = 17.4 days**

### Confidence
Medium — work items are decomposed and the rollback path is known, but API/design timing still shapes the scenario range.

### Estimate maturity
Conditional — Execute may proceed only if backend contract and designer secondary states are accepted as scenario assumptions, and no Known Unknown remains with >30% swing.

### Delivery calendar (not engineering days)
| Component | Best case | Worst case | Notes |
|---|---:|---:|---|
| Engineering days | 10.7d | 17.4d | From `### Range` above |
| Focus factor | / 0.6 | / 0.6 | One engineer at 60% focused capacity |
| External waits | +0 workdays | +2 workdays | Worst case assumes backend/design wait |
| Delivery workdays before store | ~18 workdays | ~31 workdays | Engineering / focus + explicit waits; still working days — convert to calendar via the team's week before quoting a date |
| Store review | +2–7 calendar days | +2–7 calendar days | Separate wall-clock buffer, not engineering |

### Assumptions
1. **Best case** holds when: designer error/loading/empty mockups already delivered, backend contract frozen by end of week 1, existing `ProductRepository` reused as-is.
2. **Worst case** assumes: building against a mock, contract deltas at integration, Secondary scoped late.
3. No new platform support (iOS-only).

### Known unknowns blocking final estimate
(none — remaining assumptions are tracked above and each expected swing is ≤30%)

### Estimation self-check
- [x] Affected-baseline slices trace to baseline rows.
- [x] Risk-days arithmetic matches the scenario table.
- [x] Cache PERT spread feeds the range: 0.5 in best case, 1.5 in worst; not discarded.
- [x] The PERT cache item is not reused to justify the Unknown-unknowns delta.
- [x] App/Play Store review is not included in engineering days.
- [x] Delivery calendar is separate from engineering range.
- [x] Secondary delta is skipped in best case because Secondary is scoped.
- [x] Dominant multiplier is absent, so unfamiliarity is not double-counted.
- [x] No Known Unknown above 30% remains without a required spike.
- [x] Confidence and maturity labels are present.
```

### Plan-stage gate

Before entering Execute, `Plan.md` MUST contain:

- `## Estimation`
- `### Feature type`
- `### Baseline (per work item)` with all work items and concrete ops work included
- `### Risky item PERT` when any baseline row uses PERT
- `### Risk deltas (per scenario)` with affected baseline for each applied delta
- `### Range (engineering days)` with named best/worst scenarios
- `### Confidence`
- `### Estimate maturity`
- `### Delivery calendar (not engineering days)`
- `### Assumptions`
- `### Known unknowns blocking final estimate`
- `### Estimation self-check`

Gate by maturity:

- **Draft** → Plan is not complete. Return control with `ask_user`; never enter Execute.
- **Conditional** → do NOT enter Execute silently. The named conditions are not yet accepted just because they are written down. Return control with `ask_user`, listing each condition for the user to accept, defer, or resolve. Execute may begin only after that explicit response.
- **Committable** → gate passes on this axis.

Independently of maturity, the Plan is also incomplete — return `ask_user` — if `## Estimation` is missing/malformed, a required section above is absent, or a Known Unknown could swing the estimate >30% without a required spike/resolution.

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
- **Skipping the spike for load-bearing unknowns.** A Known Unknown that can swing >30% must get a spike or resolution before final estimation.
- **Omitting confidence or maturity.** A range without quality labels looks more precise than it is.

## Calibration over time

Static deltas are a starting point, not a prescription. After each shipped feature, compare *estimated range* to *actual engineering days*. Patterns that emerge:

- Deltas consistently too low → the team is under-decomposing the landscape; push for finer work items.
- Deltas consistently too high → the team has built up tooling/library that reduces the Secondary cost; lower the Secondary delta for this codebase.

Project-specific overrides live in `CLAUDE-swift-toolkit.md ## EstimationDeltas` using the table format from Step 0. Keep overrides sparse: only encode repeatable evidence from multiple finished features, not one-off surprises.

At Done / Review time, MUST add an estimate retrospective when an estimate exists. Actual engineering days are active implementation/review/test days, not wall-clock waiting:

```markdown
## Estimate retrospective
| Estimated range | Actual engineering days | In range? | Variance reason | Calibration action |
|---:|---:|---|---|---|
| 10.7–17.4d | 18.0d | Slightly over | Backend changed response shape after integration | Keep API-in-parallel high end at +40% |
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
