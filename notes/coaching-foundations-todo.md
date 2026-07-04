# Coaching Foundations — Effective Targets And The Live Proposal Loop

Draft date: 2026-07-04.

## Purpose

The backend work that makes the coach/review loop production-real, worked
through **after `notes/fable-todo.md` and before the frontend build-out in
`notes/frontend-roadmap.md`** (specifically before frontend Phases 1 and 5,
which render what this phase produces).

This phase absorbs and expands fable-todo #4 (proposal surface wired into
projection) and #16 (`adjust_goal` apply) — both graduate from cleanup items
to core product plumbing here.

## Why This Phase Exists

The daily/weekly AI review with a coach that can suggest changes is the
likely killer feature. Getting there exposed a real tension: a plan holds
**two theories of the future** — the authored prediction (progression
tables, schedules) and the derived trajectory (what history says today
should be). Today the codebase resolves this dishonestly in two places:

1. **Completion is blind to adaptation.** `Targets.completion` evaluates
   against the authored target as written. If an evaluator lowers today's
   run to 20km after illness and the user runs 20km, the authored 25km
   target marks the day incomplete. The coach's advice breaks the user's
   streak. This single gap can kill trust in the whole loop.
2. **Adaptation is a demo.** The evaluator pipeline runs only from stories;
   `project_today` never executes it, proposals are ephemeral projection
   output, and `CommittedPlanEdits` can emit `adjust_goal` proposals that
   `Proposal.apply_proposal!` cannot apply.

The resolution, in one sentence: **the authored plan is the commitment and
the measuring stick; the coach is the renegotiation channel; every
renegotiation is recorded with receipts.** Day-to-day divergence becomes
derived adjustments (no plan edit); persistent drift becomes committed
proposals approved at review. One synthesized voice, honest scorekeeping.

## Design Principles

- The engine decides, the coach explains. All adaptation stays in the pure
  evaluator core; LLM narration comes later and adds no authority.
- Completion and streaks are always evaluated against the target that was
  actually in force — and what was in force is snapshotted, never
  retro-computed.
- Derived adjustments never mutate the plan. Committed changes only apply
  through approved proposals via core actions.
- The projection presents one effective answer per work item, with
  provenance ("25km planned → 20km today, because recent load is low after
  illness"), never two competing numbers.

## Work Items

### 1. Effective targets

The load-bearing concept. An **effective target** = authored target +
derived adjustments in force for that date, with provenance.

- [ ] Projection computes an effective target per projected work item:
      value, the authored value it replaces, source evaluator, and a
      product-language reason.
- [ ] Completion, status, and progress labels evaluate against the
      effective target, not the raw authored target.
- [ ] The target-in-force is snapshotted at log time (on the event or
      occurrence, mirroring how `recommendation_snapshot` preserves
      recommended-vs-actual for slots). Progress and streak calculations
      read snapshots; changing a plan later never rewrites past scores.
- [ ] Story: illness week — evaluator lowers the target, user hits the
      lowered target, the week scores complete, and the journal explains
      which target applied and why.

### 2. Evaluator pipelines wired into `project_today`

Expanded fable-todo #4. Adaptation moves from story harness to production.

- [ ] A plan↔bundle association: which evaluator descriptor sets apply to a
      plan (the marathon bundle is the first registrant; keep it data, not
      hardcoding).
- [ ] `Plans.project_today` assembles evaluator input from the existing
      single projection load (no second query pass) and runs the graph;
      derived adjustments merge into projected work as effective values
      (item 1).
- [ ] Fix the `owner_key` contract mismatch: `Adaptation.work_key` reads a
      field `ProjectedWork` never produces, so sessions currently key as
      `nil`. Define the work-identity contract once and share it.
- [ ] Diagnostics from evaluators flow into the projection's diagnostics
      with their existing plain-English quality.

### 3. Durable proposals

Proposals become records, not ephemeral projection output.

- [ ] A `Proposal` resource: status (proposed / approved / dismissed /
      applied / expired), source evaluator, proposed edit, evidence
      (metrics and event references used), affected fields, and
      timestamps. Plan-scoped, policy-protected like everything else.
- [ ] Projection-time committed proposals are upserted (same divergence on
      consecutive days refreshes one proposal rather than spawning
      duplicates).
- [ ] App API: list pending, approve (applies via item 4, idempotently),
      dismiss with optional reason. Dismissed proposals inform future
      evaluator runs (don't re-propose what was just declined).
- [ ] Applied proposals form an audit trail: what changed, when, on whose
      approval, proposed by which evaluator, on what evidence.

### 4. Proposal action registry

Expanded fable-todo #16. Close the emit-but-cannot-apply dead ends.

- [ ] Replace the hardcoded `apply_edit` case with a registry (mirroring
      the targets/schedules registry pattern, including support tiers so
      unknown actions degrade with diagnostics).
- [ ] Implement `adjust_goal` (per-track target amendment).
- [ ] Implement `rebase_progression` (shift/re-anchor a progression table —
      the "shift the plan right by two weeks" case from illness/holiday).
- [ ] `extend_plan` migrates into the registry unchanged.

### 5. Responsive progression

Progression position becomes a derived metric instead of a calendar index —
this is what makes progression targets match how the real world works.

- [ ] A `progression_position` capability provider (pattern:
      `recent_load_km`): computes current step from journal history —
      recent attempts, success/failure against the step's target, and
      advancement rules (advance on success, hold on failure, deload after
      N consecutive failures).
- [ ] The progression target evaluator consumes it. Two flavors, same
      vocabulary: **scheduled** (date-indexed, right for taper-to-race-day
      plans) and **responsive** (performance-gated). Authored as a field on
      the target, defaulting to scheduled for compatibility.
- [ ] Deload/repeat semantics are explicit and diagnosable ("holding at
      week 3: last two attempts missed").
- [ ] Story: user misses a step twice → position holds and the projection
      says why; user then passes → position advances.

### 6. Review consumes the loop

Review becomes a proper consumer of adaptation, with the drift rule that
keeps the plan honest.

- [ ] Review reads pending proposals and recent derived-adjustment history
      alongside its existing journal/projection summary.
- [ ] **Drift-conversion rule**: N consecutive same-direction derived
      adjustments on a track → emit a committed re-baseline proposal
      (items 3–4 make it applyable). Derived tweaks handle noise; review
      converts persistent drift into a durable, approved edit. Committed
      edits stay rare and human-approved — no ratchet churn.
- [ ] Two review shapes: **daily** (narrate today — what adapted and why,
      nothing durable) and **weekly** (durable proposals, trends,
      what-was-deliberately-not-carried-forward). Both deterministic;
      LLM narration on top is a later, optional layer.
- [ ] The planned `08_review_and_adjustment` story from
      `notes/story-api-improvement-plan.md` lands here, covering the full
      loop: adapt → drift → propose → approve → apply → re-project.

### 7. Provenance in the projection payload

What the frontend actually renders (feeds frontend-roadmap Phases 1 and 5).

- [ ] Every effective value in the projection/dashboard payload carries:
      planned value, effective value, and the reason chain in product
      language.
- [ ] Pending-proposal summaries ride the dashboard payload (count +
      cards), so Today can badge "the coach has 2 suggestions" without a
      second request.

### 8. Stretch — second forcing bundle

`notes/adaptive-marathon-lessons.md` wanted a non-marathon example to prove
the contract generalizes. Responsive progression (item 5) makes **adaptive
strength** the natural candidate — performance-gated progression, deloads,
and an `adjust_goal` consumer, sharing zero marathon code. Do it if items
1–6 leave appetite; skip without guilt otherwise.

## Sequencing And Dependencies

Order: 1 → 2 → 3 → 4 → 6, with 5 parallel after 1, and 7 alongside 2–6 as
payload shapes settle.

| Item | Depends on | Unblocks |
|---|---|---|
| 1 Effective targets | fable-todo #3 (timezones) | 2, 5, frontend Phase 1 |
| 2 Pipelines in projection | 1; fable-todo #9 (status vocab) | 3, 7 |
| 3 Durable proposals | 2 | 4, 6, frontend Phase 5 |
| 4 Action registry | 3 | 6 |
| 5 Responsive progression | 1 | 8 |
| 6 Review + drift rule | 3, 4 | frontend Phase 5, coach v1 |
| 7 Payload provenance | 2 | frontend Phases 1 & 5 |

The frontend can start its Phase 0 (contract/data layer) in parallel with
this entire phase; frontend Phase 1 wants items 1–2 and 7 done first so
Today renders effective values with provenance from day one.
