# Backend Review And Next-20 Todo

Draft date: 2026-07-04.

Findings from a full audit of the Ash data model, planning engine, API/web
layer, and roadmap docs, scored for the planned sequence: Svelte frontend
next, then a Flutter mobile app as the primary event-recording client.

## Product Vision Assessment

The vision is unusually well-articulated for an early codebase. The core loop
— plan → tracks → sessions/slots/pools → project today → log actuals → derive
state → review/adapt — is written down in `notes/story-api-improvement-plan.md`,
enforced through a controlled vocabulary (Plan, Track, Session, Slot, Item,
Pool, Event, Effect, Recommendation, Actual, Review), and proven by executable
stories that read like product copy. The V1 backend milestone is genuinely
done: 121 of 128 beans complete, the DirectGoal→Track rename fully landed, all
six target shapes and the schedule kinds project honestly, and the
review→proposal→apply loop works for `extend_plan`.

Two observations:

- **The differentiator is adaptation, and it's currently a demo.** The
  evaluator-graph architecture (capabilities, dependency ordering, derived vs
  committed proposals, the trust ladder toward third-party evaluators) is the
  genuinely novel part. But the marathon pipeline is only invoked from
  stories; `project_today` never runs it, and no API surface shows proposals
  to a user. The notes call a first-class proposal surface "probably the most
  important next product-shaping task" — agreed.
- **The generic model is both the strength and the risk.** Plan/Track/Item/
  Pool/Effect can express medication vials, marathon training, and gym
  sessions — the "translated old plan" story proves it. The cost is that ~25
  untyped JSONB `:map` attributes (`target`, `guidance`, `effect_rules`,
  `payload_schema`, `rules`, …) carry all the real semantics, enforced only at
  runtime. Reasonable while the model is moving; it will bite when mobile
  clients need stable typed contracts.

## Backend Strengths

- **Clean purity boundary.** Everything under `lib/improve/planning/` and
  `lib/improve/bundles/` is pure functions over preloaded data — zero
  `Ash`/`Repo` calls. The DB boundary is exactly `Improve.Plans`.
  Deterministic, clock-injected, fully testable without a database.
- **Registry-driven extensibility with graceful degradation.** Targets and
  schedules dispatch through implemented/recognized/unknown tiers, emitting
  diagnostics instead of crashing on unsupported shapes.
- **The journal is done right.** Append-only, void/correct with replacement
  events, effects as an auditable log, item state always derived rather than
  materialized, offline batch ingress with idempotency keys, conflict
  categories, and staleness checks — all implemented and tested at the domain
  level.
- **Authorization is resource-level.** Every plan-scoped resource carries an
  Ash policy checking `plan.user_id == actor.id`; cross-user access is blocked
  even with forged IDs, and there's a dedicated ownership-boundary test. The
  AI tools are provably read-only and actor-scoped.
- **Test depth where it matters.** ~45 test files, deep on the engine (every
  target type, evaluator graph, corrections, offline ingress), plus stories
  that double as living product specs.

## Backend Weaknesses

The pattern: **the domain layer is ahead of the delivery layer.** The engine
is solid; the HTTP surface, auth model, and operational hardening are not
ready for the frontend push, and especially not for a mobile client whose main
job is recording events.

1. **Auth is cookie-session only.** No bearer tokens, no token
   issuance/refresh endpoint, no per-device revocation — a Flutter app can't
   authenticate cleanly. (Tokens are already stored server-side via
   AshAuthentication, so the groundwork exists.)
2. **The live logging endpoints are not idempotent.** `POST /app/log-event`
   never sets `client_operation_id`/`idempotency_key`/`client_device_id`, so a
   mobile client retrying over flaky networks creates duplicate events —
   despite the dedupe machinery and partial unique indexes existing in the
   journal. The offline batch endpoint (also fully built) has no HTTP route.
3. **Everything is UTC.** No user timezone; target evaluators bucket events by
   `DateTime.to_date(effective_at)` in UTC, and date-only events default to
   20:00 UTC. A 9pm workout in New York lands on tomorrow's date. For a "did I
   do it today" product this is a correctness bug, and it gets worse once
   mobile is the capture device.
4. **Accounts has no policies.** `list_users` / `get_user_by_email` are
   callable by any actor — every user's email and name are readable.
   (Correction 2026-07-04: the originally-reported `full_name` nullability
   mismatch was a false positive — the audit misread the `down` clause of
   migration 20260623111144. DB and resource agree: nullable.)
5. **API ergonomics are pre-frontend quality.** Mixed camelCase/snake_case in
   the same payload, two different error shapes, validation errors space-joined
   into one string, broad `rescue` blocks leaking raw exception messages as
   422s, and every mutation returning the entire dashboard payload. Meanwhile
   the generated `ash_typescript` contracts exist but the frontend imports
   none of them — it hand-writes lossy types where most of the payload is
   `unknown`.
6. **Integrity and scale gaps in the schema.** No non-unique index on any
   foreign key (journal reads will seq-scan as history grows); no uniqueness
   on `SessionOccurrence` (duplicate occurrences per template/day are
   possible) or `Schedule`; no `on_delete` behavior anywhere; check-then-set
   status transitions are racy; `App.Lookup` resolves entities by loading
   whole collections and `Enum.find`, and `SamePlan` fires up to 5 existence
   queries per insert.
7. **The adaptation loop has dead ends.** `CommittedPlanEdits` can emit
   `adjust_goal` proposals that `Proposal.apply_proposal!` can't apply; the
   adaptation module keys work by an `owner_key` field the projector never
   produces; `:swapped`/`:partially_completed` slot results don't count as
   "logged," so a session with a swapped slot can never reach `:completed`.

## The Next 20 Things (importance /10)

1. **Idempotent event logging over HTTP** — bug/feature, **9/10**. Plumb
   `client_operation_id`/`idempotency_key`/`client_device_id` through
   `/app/log-event`, `/app/log-linked-event`, `/app/log-session-slot`. The
   machinery exists; only the API boundary is missing. Duplicate events on
   retry is the worst possible failure for the primary mobile use case.
2. **Bearer-token auth for API clients** — architecture, **9/10**. Token
   issuance on OTP verify, `Authorization: Bearer` acceptance in the pipeline
   alongside cookies, refresh/revocation endpoints, per-device sessions.
   Prerequisite for Flutter; also fixes the CSRF/SameSite awkwardness.
3. **User timezone and local-day semantics** — bug/architecture, **9/10**.
   Add `timezone` to `User`, convert `effective_at` to local date in all six
   target evaluators, `Review`, and `RecentLoad`; fix the 20:00-UTC date-only
   default. Do this before mobile, or historic data will be bucketed wrong
   forever.
4. **First-class proposal surface wired into projection** — feature, **8/10**.
   Run bundle evaluator pipelines inside `project_today`, expose derived and
   committed proposals (with reasons, source evaluator, approval state) in the
   dashboard payload. The product's differentiator; the frontend phase needs
   it to exist to render it. *Graduated: expanded into
   `notes/coaching-foundations-todo.md` (items 2, 3, 7) — work it there.*
5. **Lock down Accounts** — security bug, **8/10**. Add policies to
   `User`/`Token` (self-only read/update, no open `list_users`). Done
   2026-07-04 (bean `gghs`); the `full_name` half was a false positive — see
   the correction in weakness #4.
6. **Expose offline batch ingress over HTTP** (bean `natd`) — feature,
   **8/10**. The V1.1 bean. `POST /app/offline-events` in front of the
   already-tested `submit_offline_event_batch`, returning per-entry statuses.
   This plus #1 and #2 is essentially the mobile backend contract.
7. **Consistent, structured API errors** — feature, **7/10**. One error
   envelope (controller and `ErrorJSON` currently disagree), field-level
   validation errors instead of space-joined strings, and stop rescuing all
   exceptions into 422s with raw messages. Much cheaper before the Svelte work
   consumes the API than after.
8. **Unify the TS contract** — architecture, **7/10**. One casing convention
   end-to-end (payloads currently mix camelCase and snake_case at different
   depths), and make the frontend actually consume generated types — either
   extend `ash_typescript` coverage to the app endpoints or generate types
   from the UiApi payloads. Add a codegen drift-check to `precommit`. Directly
   de-risks the entire frontend phase.
9. **Fix the slot-status vocabulary** — bug, **7/10**. Done 2026-07-04 (bean
   `2hxc`). Correction: swapped-and-logged slots *did* count as logged via
   `event_instance_id`, so sessions could complete — now proven by a
   regression test. The real defect was `:partially_completed` existing as an
   unreachable enum value across four layers while the projector emits
   `:partial`; removed everywhere and TS contracts regenerated.
10. **Index migration for FKs and hot paths** — optimization, **7/10**. There
    is no non-unique index in the whole schema. At minimum:
    `event_instances(plan_id, effective_at)`,
    `item_effects(event_instance_id)`,
    `event_item_links(event_instance_id, item_id)`,
    `slot_results(session_occurrence_id)`. Cheap now, painful later.
11. **Missing uniqueness identities** — integrity, **7/10**.
    `SessionOccurrence` unique on `(plan_id, session_template_id,
    planned_for)` (duplicates are creatable today via
    `start_projected_session!`), and a sane identity for `Schedule`. Decide
    `on_delete` behavior for the `User.destroy` path while in there.
12. **Authoring APIs: sessions, items, event types, track edit** — feature,
    **7/10**. The four deferred UI beans (`8jbf`, `iycz`, `nbg8`, `vlya`) all
    need app-layer CRUD APIs that don't exist yet. The backend halves of these
    beans unblock the frontend phase.
13. **Bounded journal reads** — optimization, **6/10**. `read_journal` loads
    every event for a plan and callers slice in memory (`Enum.take(-5)`);
    `projection_load` pulls all history per projection. Add limits/keyset
    pagination at the query layer before journals grow. Feeds bean `elb2`
    (read models) later.
14. **Slim mutation responses** — optimization, **6/10**. Every write returns
    the full dashboard (plans + today + journal + complete plan detail).
    Return the affected slice, or add a delta/`changed-since` mechanism.
    Directly translates to mobile battery/bandwidth.
15. **Stop leaking internals via broad rescues** — bug, **6/10**. Done
    2026-07-04 (bean `svdo`): removed the dead catch-all clauses so only
    expected error types rescue to 422; everything else propagates to a
    logged 500. Proper error envelope follows in #7.
16. **Implement `adjust_goal` apply and a proposal-action registry** —
    feature, **5/10**. Close the dead-end where evaluators emit proposals the
    apply path can't execute; also fix `Adaptation.work_key` reading an
    `owner_key` field the projector never produces (sessions currently key as
    `nil`). *Graduated: expanded into `notes/coaching-foundations-todo.md`
    (items 2 and 4) — no longer a 5/10 cleanup; it's core coaching plumbing.*
17. **Fix the Lookup/SamePlan query patterns** — optimization, **5/10**.
    `App.Lookup` fetches entire collections per lookup and
    `Logging.item_links` does it per link; `SamePlan` fires an existence query
    per referenced field on every write (5 per event log). Batch the reference
    checks and add keyed fetches.
18. **Atomic state transitions** — bug, **5/10**. The `data_one_of`
    check-then-`set_attribute` pattern on session/slot/event transitions is
    racy, and `require_atomic? false` is widespread. Low concurrency today,
    but offline batch replay (#6) raises the odds; move guards into atomic
    updates where Ash allows.
19. **Rate limiting for real deployment** — hardening, **5/10**. OTP limits
    are per-email only (rotation bypass, victim griefing — add per-IP),
    nothing on `/app/*` or `/rpc/*`, and the Hammer ETS backend is
    single-node. Also: move the hardcoded session `signing_salt` to config and
    add CORS for non-same-origin clients.
20. **Shared key-normalization helper and registry consolidation** — refactor,
    **4/10**. The `map_value`/dual atom-string-key helper is copy-pasted
    across ~12 modules, illness/injury logic is duplicated between
    `Adaptation` and `CommittedPlanEdits`, and adding a schedule kind means
    editing four disconnected lists. One support module kills a whole class of
    future shotgun edits.

## Near Misses

Didn't crack the top 20:

- Oban for scheduled jobs/reminders (becomes important with mobile push,
  premature now).
- `completion_evaluator` silently falls back to `Fixed` for unknown target
  types — the diagnostic path and completion path diverge.
- `RecentLoad.running_track?` treats any km-unit track (cycling, rowing) as
  running load.
- The monthly-schedule day-31 clamp fires on Feb 28/29 with no diagnostic.
- Diagnostics double-reverse ordering quirk in `Projector.project_today`.

## Suggested Sequencing

- **Quick wins, do immediately:** #5 (Accounts lockdown), #9 (slot status),
  #15 (broad rescues).
- **API-readiness block, before serious frontend work:** #1–#3 (idempotency,
  bearer tokens, timezones) and #6–#8 (offline ingress, structured errors,
  contract unification).
- **Product-shaping:** #4 (proposal surface) and #12 (authoring APIs).
- The rest can interleave.
