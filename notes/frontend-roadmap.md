# Frontend Roadmap — Web Studio To Mobile-Ready

Draft date: 2026-07-04.

## Purpose

The plan for building out the Svelte web app after the backend hardening pass
(now archived at `notes/archive/fable-todo.md`; only four low-priority beans
remain from it — `oim8`, `grxa`, `e0u0`, `ilos` — none of which block this
roadmap). The goal of this stage is the **main usage loop,
usable every day**: see today, log what happened, correct mistakes, browse
history, author and adjust a plan. Light AI where it earns its place — no
full coaching capability yet. The stage ends at the **mobile gate**: the
point where the API surface and product shapes are proven enough to start
the Flutter app, with web work continuing in parallel.

## Where We Are

The shell is genuinely done: OTP auth + profile completion, plan
create/edit/switch, demo plan install, date navigation in the top bar,
theme toggle, toasts, dialog animations. Nine routes exist (Today, Journal,
Calendar, Plan, Progress, Sessions, Inventory, Event Types, Resource Types)
— all rendering `PlaceholderPage`. `LogDialog` and `CheckInDialog` are
stubs. State is a single dashboard-snapshot store (`appState.ts`). The API
types are no longer lossy — bean `3faz` landed a fully typed dashboard
payload in `types.ts` (only intentional `unknown` corners remain:
`previousEvents`, `explanations`, and the variable parts of
`TargetProgress`).

So the work is: harden the data layer once, then fill the shell one
vertical slice at a time, Today-first.

## Phase 0 — Contract And Data Layer (the enabler)

Do this first and everything after gets cheaper. Its server-side
prerequisites (structured errors, contract unification) landed 2026-07-04,
so this phase is unblocked.

- **Full payload types.** Mostly done via bean `3faz`: `types.ts` is
  hand-written but complete and casing-consistent. Remaining: tighten the
  deliberate `unknown` corners a page will actually read (`explanations`,
  `previousEvents`, per-target-type `TargetProgress` variants).
- **API client upgrade** (`improveClient.ts`): structured error type with
  field-level errors surfaced to forms; 401 handling that routes to login
  (session expiry mid-use); a single request helper so idempotency keys can
  be attached later without touching call sites.
- **Store slices.** Split the monolithic dashboard store into `today`,
  `journal`, `planDetail`, and `plans` slices with a shared refresh, so
  pages can refresh what they touched instead of always reloading the
  world. Slim mutation responses already landed server-side (bean `f7jj`),
  so the slices have a payload shape to align with.
- **Router: parameterized routes.** The flat `AppRoute` union can't express
  `/items/:id` or `/sessions/:id`. Add param support now; detail pages
  arrive in Phases 3–4.
- **Form kit.** The UI kit has Card/Badge/Empty/Loading; add the form
  primitives every authoring slice needs: text/number/date inputs, select,
  toggle, field-error display, confirm dialog, dialog form pattern with
  submit/disable/error states.
- **Vocabulary decision.** The sidebar says "Resource Types" and
  "Inventory"; the backend product vocabulary says Item/ItemType. Pick the
  product words once (per `notes/story-api-improvement-plan.md`, UI copy
  and API names should agree) and apply everywhere before the pages exist.

## Phase 1 — Today, Read Side (the heart of the product)

The screen users see most. Render the projection honestly.

- **Work list.** Projected sessions and tracks for the selected date:
  title, status (planned / started / partial / completed / missed /
  on_hold / skipped), target progress ("2 of 3 this week", metric
  quantities, checklist items), schedule context ("every Tuesday").
- **Session cards.** Slots with recommended items and counts; pool names;
  what's been logged so far ("3 of 4 slots logged").
- **Time off.** On-hold styling with the window's reason ("Fully off —
  travel until 12/07").
- **Diagnostics and explanations.** The projector emits them; show them.
  Authoring problems ("unknown target type") surface here as actionable
  warnings linking to the authoring page — this is what makes the studio
  self-correcting.
- **Upcoming strip.** The dashboard payload already carries upcoming days;
  render a compact preview under today's work.
- Empty states: no plan → demo install / create; plan with no work today →
  "rest day" not "nothing".

## Phase 2 — Logging, Write Side (completes the core loop)

After this phase the app is daily-usable and the mobile capture contract is
effectively designed.

- **Quick log from a work card.** One click on a track card → prefilled log
  (event type, date, suggested payload from target/guidance) → confirm.
  Target progress and status update immediately.
- **Log dialog (the real one).** Choose event type → dynamic form driven by
  `payload_schema` (quantity + unit first-class; generic fields after);
  link items by role where the event type requires it; note field;
  effective time defaulting sensibly (timezone/local-day semantics are
  already live backend-side, bean `pxze`).
- **Session flow.** Start session → slot-by-slot: accept recommendation /
  swap (pick from pool, filtered by environment) / skip → complete or skip
  session. Status transitions mirror the backend state machine; the
  slot-status vocabulary fix (bean `2hxc`) already landed.
- **Check-in flow.** Define it properly: an end-of-day sweep of remaining
  work — mark done / skip with reason / leave. Currently a stub with no
  semantics; this is its product definition.
- **Corrections.** From any logged event: "fix this" → edit → replacement
  event, original marked corrected. Surfaced both here and in Journal.
- **Idempotency plumbed through**: the log endpoints already accept
  operation IDs (bean `fian`); the client generates one per log submission
  — proving the exact contract mobile will use.

## Phase 3 — Journal And Calendar (trust and time)

- **Journal page.** Newest-first event list with pagination (backend
  pagination landed, bean `33hn`); filters by track/item/event type/status;
  corrected and
  voided badges with links between original and replacement; event detail
  view showing payload, linked items, and the item effects it produced.
- **Calendar page.** Month/week grid of projected + actual: which days had
  work, what completed, streaks visible at a glance. Backend note:
  `Plans.project_dates` exists domain-side but has no HTTP endpoint — add
  a ranged projection endpoint (fits naturally with the payload-slicing
  shape from bean `f7jj`).
- **Inventory page (read side).** Stateful items with derived current
  quantity, low-quantity warnings, and per-item effect history — the vial
  demo made visible. (Authoring arrives in Phase 4.)

## Phase 4 — Plan Authoring (the studio earns its name)

The backend halves — authoring CRUD APIs for sessions, items, event types,
and track edit — landed 2026-07-04 (bean `sqzg`), so this phase is pure
frontend work. Order within the phase follows the dependency chain:
types → items/pools → sessions.

- **Plan page.** Overview of the whole plan: tracks, sessions, schedules,
  time-off windows, with edit entry points everywhere.
- **Track authoring.** Create exists; add edit. A target builder for all
  six shapes (fixed / metric / checklist / period-total / progression /
  adaptive) with plain-language previews ("3 times per week, any day"), and
  a schedule builder for the schedule kinds.
- **Event Types and Item Types authoring.** Friendly forms first (name,
  what it records, quantity unit); raw `payload_schema` / `effect_rules`
  behind an "advanced" disclosure. This is the riskiest UI in the app —
  keep the simple path simple.
- **Items, pools, environments.** Item CRUD + archive; pool membership
  management; environment editing with available-item pickers; item detail
  page (route param work from Phase 0 pays off).
- **Session template authoring.** Template + slots + pool wiring + counts +
  optional flags; live preview of what the projected session will look
  like, using the same components as Today.
- **Time-off windows.** Simple CRUD with calendar-range picking; visible
  consequences ("this puts 4 sessions on hold").

## Phase 5 — Progress, Review, And The Proposal Surface

- **Progress page.** Per-track history: completion over time, period
  totals, progression curves, streaks; item quantity trends for stateful
  items. Needs a small ranged-history endpoint (journal aggregated by
  day/week — decide alongside bean `elb2` read-model investigation).
- **Review.** Run the deterministic `App.Review` on demand: what happened
  this week, what was missed, suggested changes with reasons.
- **Proposal surface v1.** The backend side is fully live: durable
  proposals (bean `8cxq`) and the proposal-action registry with
  `adjust_goal` and rebalancing (bean `xi85`). Proposals rendered as cards
  — what would change, why, evidence — with approve/dismiss. Approve
  applies through `App.apply_proposal!`. Start with `extend_plan`; grow as
  the apply registry grows. This is the seed of the whole coaching product
  and the mobile app's most important screen after Today.

### Light AI in this stage (optional, each independently shippable)

Small ash_ai features that fit "AI where needed" without building the coach:

- **Review narration.** A prompt-backed action that turns the deterministic
  review output into three friendly sentences. Read-only, low risk, high
  perceived value.
- **AI plan drafting.** A chat panel that interviews the user and emits a
  `PlanDraft`; the existing validate → preview → import pipeline is the
  confirmation UI. This de-risks the mobile authoring story (vision doc
  Pillar 1) while the web forms remain the fallback.
- **Natural-language quick log.** "12k easy run, felt good" → structured
  event via prompt-backed action → normal confirm dialog. A dry run for
  mobile voice capture.

## Phase 6 — Hardening And The Mobile Gate

- **Onboarding.** First-run: create-or-demo, one guided track, first log,
  first check-in. A new user reaches a logged event in under three minutes.
- **Resilience.** Error boundary; session-expiry re-auth without losing
  work; retry-with-idempotency on flaky writes; skeleton loading states.
- **Quality pass.** Keyboard navigation and focus management in dialogs;
  a11y sweep; bundle/perf check; visual polish debt.
- **Test layer.** Playwright smoke suite driving the real backend with the
  demo plans: login → install demo → log → correct → review. This becomes
  the regression net for both web and API — the same flows mobile will hit.

### Mobile gate — start Flutter when ALL of these are true

1. Today (Phase 1) and Logging (Phase 2) are complete and daily-usable.
2. Bearer-token auth, idempotent logging, and the offline batch endpoint
   are exercised by the web app or tests (all three are live backend-side
   as of 2026-07-04 — beans `fian`, `9bkp`, `natd` — so this is now about
   exercising them, not building them).
3. The dashboard/today payload shape has survived a few weeks of real use
   without breaking changes — the contract is stable enough to build a
   second client against.
4. Journal read + corrections work (mobile needs "did it save?" trust).

Phases 3–5 then run in parallel with early mobile work: the mobile app only
needs the capture loop; the studio keeps growing on the web.

## Sequencing Summary

All backend dependencies this roadmap was written against have landed
(the hardening pass and the coaching-foundations phase are both complete
and archived under `notes/archive/`). Only two small backend items remain,
and both are new work this roadmap itself proposes:

| Phase | Delivers | Backend dependencies |
|---|---|---|
| 0 | Typed contract, store slices, router params, form kit | none — landed |
| 1 | Today read view | none — effective targets + provenance landed |
| 2 | Logging, sessions, check-in, corrections | none — landed |
| 3 | Journal, calendar, inventory read | ranged projection endpoint (new) |
| 4 | Full plan authoring | none — authoring APIs landed |
| 5 | Progress, review, proposals (+ light AI) | ranged-history endpoint (new) |
| 6 | Onboarding, hardening, smoke tests, mobile gate | none — landed |

The mobile gate sits after Phase 2 plus exercising the auth/offline
endpoints — Phases 3–5 are web-studio depth, not mobile blockers.

Note: the coaching-foundations phase (effective targets, live proposal
loop, provenance) landed before this roadmap starts, so Phase 1 can render
effective targets with provenance from day one as intended — nothing needs
retrofitting.
