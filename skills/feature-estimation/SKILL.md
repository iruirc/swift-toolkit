---
name: feature-estimation
description: "Use when estimating mobile / app feature work — after `feature-landscape` produced work-items. Converts an ideal-day baseline into a calibrated day range using additive risk deltas (unknowns, unscoped secondary requirements, parallel API, binary-distribution, OS fragmentation), at most one dominant multiplier for unfamiliar tech, and a separate App/Play Store review calendar buffer. Output is a range anchored to named scenarios, never a point estimate."
---

# Feature Estimation

Estimates fail because they ignore the cost of what nobody wrote down: error states, the App Store review window, the engineer's unfamiliarity with the module, the API contract changing mid-sprint. This skill adds a set of mobile-specific **risk deltas** on top of a decomposed baseline and produces a calibrated *range* anchored to named scenarios — never a single number.

> **Related skills:**
> - `feature-landscape` — produces the work-items list this skill consumes
> - `feature-requirements` — Secondary list and Known Unknowns directly drive the deltas
> - `mobile-ops-checklist` — Applicable ops items add concrete days (feature flag wiring, analytics dashboards, on-call runbook)

## When to use

- Plan stage of any workflow (`workflow-feature`, `workflow-bug`, `workflow-refactor`) after the landscape is drawn
- Sprint planning — single-feature commitment to a sprint
- Trade-off discussion with stakeholders ("can this ship by Q3?")
- Direct invocation when the user asks "how long will this take?"

## Inputs

- `Research.md ## Landscape ### Work items` — decomposed list with each item ≤ 2 days
- `Research.md ## Requirements` — Secondary table + Known Unknowns
- Project stack from `CLAUDE-swift-toolkit.md` — for stack-specific deltas (e.g. Android fragmentation only applies if cross-platform)
- API readiness state — built / in-parallel / not started
- Engineer familiarity with the module — first time / occasional / fluent
- Hard deadline presence (yes / no)

## The model

```
adjusted = baseline × (1 + Σ risk_deltas) × dominant_multiplier?
total_calendar = adjusted + store_buffer
```

- **Risk deltas are additive**, not multiplicative. Each delta is a percentage of the baseline; they sum, then scale the baseline once. Risk buffers are slack on the same work — multiplying them double-counts the same uncertainty and inflates an 8-day feature past 25 days. Adding them keeps the adjustment in the realistic 1.5–2.5× band.
- **At most one dominant multiplier** is allowed, applied after the delta sum, and only when a single factor genuinely rescales the *whole* effort (e.g. first time on a new framework touches every item). Never stack two multipliers.
- **Store review is a calendar buffer**, kept on its own line — it is wall-clock waiting, not engineering days. Never fold it into the engineering-day figure.

### Step 1 — Baseline

For each work item from `feature-landscape`, estimate **ideal developer-days**: a single engineer, no interruptions, full knowledge of the codebase, no waiting on anyone. Sum per-item baselines.

Items are already ≤ 2 days (enforced by `feature-landscape` Step 4). If any item is larger, return to the landscape and decompose further — don't estimate at the wrong granularity.

### Step 2 — Apply risk deltas

Sum every applicable delta below into a single risk factor, then scale the baseline by `(1 + Σ deltas)`. Record each delta used with its justification.

| Risk delta | Value | When applies |
|---|---|---|
| Unknown unknowns | **+30%–50%** | Always. +30% for well-known territory, +50% for greenfield. |
| Secondary requirements not yet scoped | **+40%–70%** | When `feature-requirements ### Secondary` still has Pending rows |
| API in parallel | **+30%–40%** | API being built same sprint — contract may shift |
| Binary distribution risk | **+20%** | Always for iOS/macOS apps (no instant rollback) |
| OS / device fragmentation | **+20%–30%** | Android only — Custom UI, Camera, Media. iOS-only project: skip. |

**Dominant multiplier (at most one, applied after the delta sum):**

| Multiplier | Value | When applies |
|---|---|---|
| New tech / unfamiliar module | **×1.5–2.0** | First time touching this area; new SDK; new framework that touches most work items |

**Calendar buffer (separate line, not engineering days):**

| Buffer | Value | When applies |
|---|---|---|
| App / Play Store review | **+2–7 calendar days** | Any hard deadline that requires a store-submitted build |

**Rules:**
- Deltas **add**, then scale the baseline once. App Store buffer is reported on its own line as calendar time.
- Don't double-count: if Secondary is fully scoped (no Pending rows), don't apply the Secondary delta — those days are already in the baseline.
- Don't push Unknown Unknowns above +50% — beyond that you're guessing, not buffering. Decompose the landscape further instead.
- Use the dominant multiplier sparingly: only when one factor rescales the whole effort. Two multipliers is a red flag — fold the weaker one back into a delta.
- Cross-platform = two estimates, not one. Each platform gets its own baseline + deltas, then the totals sum. Never `× 0.5`.

### Step 3 — Known unknowns gate

List every Known Unknown from `feature-requirements ### Known unknowns`. For each:

- If unresolved at estimation time → the estimate is **conditional** ("9–12 days *assuming* the API contract is finalized this week")
- If a Known Unknown could swing the estimate >30% → return to `feature-requirements`, the unknown is too load-bearing to leave open

### Step 4 — Communicate as a scenario-anchored range

Output is **always** a range, never a point. **Each end of the range is a named scenario**, not a min/max product of the deltas. Pick which deltas apply under each scenario and which assumptions hold.

- **Low end** = optimistic scenario: load-bearing assumptions hold (API frozen, Secondary already scoped), so fewer deltas apply and applicable ones sit at their low value.
- **High end** = pessimistic scenario: assumptions break (build against a mock, Secondary discovered late), more deltas apply at their high value.

State the assumptions that define each scenario. The range is the spread between two coherent worlds — not the arithmetic min and max of every knob simultaneously (those extremes are jointly near-impossible and produce a falsely wide band).

Example:

> "**12 days** — *best case*: API contract finalized this week, existing `CartRepository` reused, Secondary mockups already delivered. Only unknown-unknowns (+30%) and binary-distribution (+20%) apply.
> **22 days** — *worst case*: building against a mock, contract deltas surface at integration, Secondary left for last. Unknowns (+50%) + Secondary (+70%) + API-parallel (+40%) + binary (+20%) apply.
> **+2–7 calendar days** App Store review buffer on top, when a hard deadline applies — this is wall-clock waiting, not engineering days."

If an assumption breaks, the estimate moves toward the high end — and that's expected.

## Output artifact

Write into the active task's `Plan.md` under heading `## Estimation`. Structure:

```markdown
## Estimation

### Baseline (per work item)
| Item | Layer | Ideal days |
|---|---|---|
| Define CartItem / Order / PaymentStatus | Domain | 0.5 |
| `CartRepository` add/remove/clear | Repository | 1.0 |
| Local cache (Core Data) | Repository | 1.5 |
| `CartViewModel` state transitions | State | 1.0 |
| ... | ... | ... |
| **Baseline total** | | **8.0 days** |

### Risk deltas (per scenario)
| Risk delta | Low (best case) | High (worst case) | Justification |
|---|---|---|---|
| Unknown unknowns | +30% | +50% | Mid-familiarity territory, two unresolved known unknowns |
| Secondary not scoped | — (scoped) | +70% | Designer mockups: delivered in best case, late in worst |
| API in parallel | — (frozen) | +40% | Best: contract frozen wk1. Worst: built against mock |
| Binary distribution | +20% | +20% | iOS app — no hotfix path |
| **Σ deltas** | **+50%** | **+180%** | |
| Dominant multiplier | none | none | No new-framework work this feature |

### Range
**Low (best case):  8.0 × (1 + 0.50) = 12.0 days**
**High (worst case): 8.0 × (1 + 1.80) = 22.4 days**
**+ 2–7 calendar days** App Store review buffer (calendar, not engineering) when a hard deadline applies.

### Assumptions
1. **Best case** holds when: designer error/loading/empty mockups already delivered, backend contract frozen by end of week 1, existing `ProductRepository` reused as-is.
2. **Worst case** assumes: building against a mock, contract deltas at integration, Secondary scoped late.
3. No new platform support (iOS-only).

### Known unknowns blocking final estimate
- [u1] Designer behavior for offline checkout — owner: designer — resolution required before lockdown
- [u2] Payment-gateway error taxonomy — owner: backend
```

**Idempotency:** if `## Estimation` already exists in `Plan.md`, prompt the user before overwriting. Re-estimation is normal mid-feature — keep the previous version under `### Estimation history` with a date.

## Anti-patterns to avoid

- **Happy-path only estimate.** Ignoring Secondary turns a 10-day feature into a 20-day surprise.
- **"It's just a UI change."** UI almost always touches state, tests, analytics, and edge cases. The Secondary delta exists for exactly this.
- **Multiplying risk buffers.** Five compounding multipliers turn an 8-day feature into 26+ days of fiction. Risk deltas are slack on the same work — they add, they don't multiply.
- **Min/max product as the range.** "All knobs at minimum" and "all knobs at maximum" are jointly near-impossible. Anchor each end to a coherent scenario instead.
- **Shared estimate across platforms.** iOS and Android are not "the same work × 2 people." Each is its own decomposition, baseline, and delta set.
- **Point estimate without decomposition.** "Probably 2 weeks" with no work-item list is fiction. Always decompose first via `feature-landscape`.
- **Velocity-based without breakdown.** Story points are a team-private calibration on top of decomposition — not a replacement for it.
- **Delta without justification.** Each delta must be tied to a concrete observation. "Felt risky" is not a justification.
- **Communicating a single number to stakeholders.** Always give a range with scenarios. If forced into a single number, give the high end.
- **Folding store review into engineering days.** Review windows are calendar time, not engineering time. Always surface them on their own line.

## Calibration over time

Static deltas are a starting point, not a prescription. After each shipped feature, compare *estimated range* to *actual days*. Patterns that emerge:

- Deltas consistently too low → the team is under-decomposing the landscape; push for finer work items.
- Deltas consistently too high → the team has built up tooling/library that reduces the Secondary cost; lower the Secondary delta for this codebase.

These calibrations live in the team's retro notes, not in this skill — the skill stays stable, the team's project-specific overrides go into the team's own playbook. (Future: an optional `## EstimationDeltas` section in `CLAUDE-swift-toolkit.md` can override the defaults — not yet supported.)

## Platform-specific notes

- **SPM library / CLI** — Skip App Store buffer; skip OS fragmentation; binary-distribution delta still applies if the library is shipped as a binary artifact (e.g. xcframework).
- **macOS app distributed via Mac App Store** — App Store buffer applies; via Developer ID / direct distribution → skip the buffer but add notarization time (~1 hour, not days).
- **iOS app** — All deltas in scope.

## What this skill does NOT do

- Does NOT produce a single number — only ranges.
- Does NOT promise calendar dates — engineering output is *working days*; the store buffer is the only calendar figure, kept separate.
- Does NOT decide priority or scope — that's the product / planning conversation.
- Does NOT estimate features without a landscape — return to `feature-landscape` first if no work-items list exists.
