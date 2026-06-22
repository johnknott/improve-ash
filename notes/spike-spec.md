# Improve Ash Headless POC Spec

## Purpose

Build a headless proof-of-concept for **Improve** using Ash, AshPostgres, Postgres, and plain Elixir.

This is not a full product build. It is a spike to decide whether the Ash-based architecture is smaller, clearer, and more maintainable than the previous Go/sqlc/Postgres implementation.

The POC should prove the core domain model and workflows without building a web UI, admin section, billing, full auth, or a mobile client.

The main output is a working Elixir/Phoenix/Ash application with:

- Ash resources and actions for the Improve core model.
- Postgres persistence via AshPostgres.
- A pure deterministic planning package.
- Scenario tests that exercise real product workflows.
- Seed/demo data for a gym plan and a vial inventory plan.
- Generated TypeScript contract smoke test via AshTypescript.
- A small AshAI tool exposure experiment.
- Optional AshEvents audit logging if it remains simple.

The frontend can come later as a Vite/React/TypeScript/shadcn app using AshTypescript-generated client code. Do not build the React app in this POC.

---

## Product Context

Improve is a personal planning and progress app.

It helps a person turn an intention into a living plan. A plan can say what should happen, help the user do it, remember what actually happened, understand what changed because of it, and use that history to make better suggestions next time.

The model must support multiple domains without hard-coding the platform around one of them:

- Gym training.
- Reading.
- Study routines.
- Running or cycling.
- Medication, peptide, or supplement inventory.
- Household supplies.
- Project habits.
- Metrics such as bodyweight, sleep, mood, symptoms, or resting heart rate.

The shared shape is:

1. The user has a plan.
2. The plan contains items the user may use, choose, track, or affect.
3. The plan describes sessions, direct goals, targets, schedules, and policies.
4. The user logs events that say what actually happened.
5. Some events change the state of items in the plan.
6. The app derives progress and state from the journal.
7. The app uses deterministic rules to suggest what should happen next.
8. An AI coach can explain, review, and propose changes using structured facts.

---

## Core Architectural Principle

Build a **headless product kernel**.

The POC should be usable through:

- ExUnit tests.
- Seed scripts.
- IEx.
- Ash code interfaces.
- Optional mix tasks.
- Generated TypeScript type/client output.
- Optional AshAI tool calls.

No browser UI is required.

The goal is to answer:

> Can we define Improve actions once and reuse them cleanly as backend domain operations, typed client calls, assistant tools, validations, and auditable writes?

---

## Hard Constraints

### Must Do

- Use Elixir, Phoenix, Ash, AshPostgres, and Postgres.
- Use UUID primary keys.
- Use Ash code interfaces for the main domain actions.
- Keep deterministic planning logic in plain Elixir modules.
- Keep planning modules free of database access, HTTP, AI calls, randomness, and wall-clock reads.
- Store journal events as first-class domain records.
- Store item effects as first-class domain records.
- Derive item state from starting facts plus active item effects.
- Model gym and vial inventory examples.
- Write scenario tests that prove the core workflows.
- Generate TypeScript contract output with AshTypescript.
- Expose a tiny set of read-only AshAI tools.
- Keep the implementation intentionally small.

### Must Not Do

- Do not build React, LiveView, or any product UI.
- Do not build an admin section.
- Do not build billing.
- Do not build Stripe.
- Do not build full passwordless auth.
- Do not build profile photos.
- Do not build a mobile client.
- Do not build a full offline sync system.
- Do not build a full plan store.
- Do not over-generalize before the scenario tests pass.
- Do not make AshEvents the user-facing journal event model.
- Do not let AI tools write important user data directly without a proposal/approval path.

---

## Recommended Dependencies

Use current stable versions when implementing, not necessarily the versions listed in this spec.

Required:

- `ash`
- `ash_postgres`
- `phoenix`
- `postgrex`
- `ash_typescript`

Strongly recommended:

- `ash_ai`
- `ash_oban` if required by the AshAI path chosen
- `oban` if background jobs become necessary for the generated/experimental AI flow

Optional if simple:

- `ash_events`
- `ash_json_api`

Defer unless needed:

- `ash_authentication`
- `ash_authentication_phoenix`
- `ash_admin`
- `ash_phoenix`
- `ash_graphql`
- Stripe/billing libraries

---

## Application Shape

Suggested app/module structure:

```text
lib/improve/
  accounts/
    user.ex

  plans/
    plan.ex
    item_type.ex
    item.ex
    pool.ex
    pool_membership.ex
    environment.ex
    event_type.ex
    session_template.ex
    session_slot.ex
    direct_goal.ex
    schedule.ex

  journal/
    event_instance.ex
    event_item_link.ex
    item_effect.ex

  sessions/
    session_occurrence.ex
    slot_result.ex

  planning/
    input.ex
    output.ex
    projector.ex
    recommender.ex
    diagnostics.ex
    item_state.ex

  ai/
    tools.ex

  fixtures/
    gym_plan.ex
    vial_plan.ex
```

Suggested domains:

```text
Improve.Accounts
Improve.Plans
Improve.Journal
Improve.Sessions
```

The exact module layout can change if a simpler Ash domain layout emerges, but keep the boundaries clear.

---

## Resource Model

### User

Minimal seeded user only.

Required fields:

- `id`
- `email`
- `full_name`
- timestamps

Do not implement real authentication. Scenario tests can create or seed a user.

---

### Plan

A user's working copy of an intention.

Required fields:

- `id`
- `user_id`
- `name`
- `intention`
- `start_date`
- `end_date`
- `status`
- `source_kind`
- `source_key`
- timestamps

Suggested `status` values:

- `draft`
- `active`
- `archived`

Relationships:

- belongs to User
- has many ItemTypes
- has many Items
- has many Pools
- has many Environments
- has many EventTypes
- has many SessionTemplates
- has many DirectGoals
- has many Schedules
- has many SessionOccurrences
- has many EventInstances

Actions:

- create
- read
- update
- archive
- install_gym_demo_plan
- install_vial_demo_plan
- project_today
- project_range
- get_summary

Notes:

- `install_*_demo_plan` actions may be plain code interface functions backed by transactions rather than deeply nested Ash creates if that is clearer.
- `project_today` and `project_range` must call the pure planning package and must not mutate history.

---

### ItemType

Describes what kind of thing an item is.

Examples:

- Exercise
- Cardio machine
- Gym environment
- Peptide vial
- Supply
- Book

Required fields:

- `id`
- `plan_id`
- `key`
- `name`
- `description`
- `facts_schema`
- `display_hints`
- timestamps

Use JSON/JSONB for:

- `facts_schema`
- `display_hints`

Relationships:

- belongs to Plan
- has many Items

Validations:

- `key` unique within plan.
- `name` required.
- `facts_schema` must be valid JSON-compatible data.

---

### Item

Any concrete thing inside a plan that can be selected, used, tracked, linked to an event, or affected by an event.

Examples:

- Chest Press
- Lat Pulldown
- JD Gym
- Retatrutide vial 1
- Syringe box
- The Hobbit

Required fields:

- `id`
- `plan_id`
- `item_type_id`
- `key`
- `name`
- `facts`
- `stateful`
- `archived_at`
- timestamps

Use JSON/JSONB for:

- `facts`

Relationships:

- belongs to Plan
- belongs to ItemType
- has many PoolMemberships
- has many EventItemLinks
- has many ItemEffects

Validations:

- `key` unique within plan.
- `facts` should conform to the associated ItemType's `facts_schema` where practical.
- Do not overbuild schema validation, but include enough structure to prove diagnostics.

Actions:

- create
- read
- update
- archive
- get_state

`get_state` should call the pure item state calculator and return starting facts plus active effects.

---

### Pool

A named group of items that can satisfy a role.

Examples:

- Push exercises
- Pull exercises
- Cardio machines
- Peptide supplies

Required fields:

- `id`
- `plan_id`
- `key`
- `name`
- `description`
- timestamps

Relationships:

- belongs to Plan
- has many PoolMemberships
- many-to-many Items through PoolMemberships

Validations:

- `key` unique within plan.

---

### PoolMembership

Connects an item to a pool.

Required fields:

- `id`
- `plan_id`
- `pool_id`
- `item_id`
- `metadata`
- timestamps

Use JSON/JSONB for:

- `metadata`

Validations:

- pool and item must belong to same plan.
- `(pool_id, item_id)` unique.

---

### Environment

Context where something happens.

Examples:

- JD Gym
- Home
- Travel
- Outdoors

For this POC, implement Environment as its own resource.

Required fields:

- `id`
- `plan_id`
- `key`
- `name`
- `description`
- `available_item_ids` or equivalent relationship
- timestamps

Simplify if needed:

- It is acceptable to store availability as JSONB initially.
- Prefer a join table if it remains small and clear.

---

### EventType

Describes what kind of thing can be logged.

Examples:

- Workout exercise performed
- Cardio block performed
- Peptide dose taken
- Vial prepared
- Inventory correction
- Pages read
- Metric recorded

Required fields:

- `id`
- `plan_id`
- `key`
- `name`
- `description`
- `payload_schema`
- `item_link_roles`
- `effect_rules`
- timestamps

Use JSON/JSONB for:

- `payload_schema`
- `item_link_roles`
- `effect_rules`

Example `item_link_roles`:

```json
[
  {"role": "exercise", "item_type_key": "exercise", "required": true},
  {"role": "environment", "item_type_key": "gym_environment", "required": false}
]
```

Example `effect_rules` for dose event:

```json
[
  {
    "role": "source_vial",
    "effect_type": "subtract_quantity",
    "quantity_path": "amount",
    "unit_path": "unit"
  }
]
```

Validations:

- `key` unique within plan.
- item link roles must refer to existing item type keys where practical.
- effect rules must refer to declared item link roles.

---

### SessionTemplate

Reusable recipe for a planned block of activity.

Example:

- Upper-biased gym visit

Required fields:

- `id`
- `plan_id`
- `key`
- `name`
- `description`
- `environment_id`
- `completion_policy`
- `missed_policy`
- timestamps

Use JSON/JSONB for:

- `completion_policy`
- `missed_policy`

Relationships:

- belongs to Plan
- optionally belongs to Environment
- has many SessionSlots
- has one or more Schedules

Validations:

- `key` unique within plan.

---

### SessionSlot

One requirement inside a session template.

Examples:

- 2 from Push
- 2 from Pull
- 1 from Cardio

Required fields:

- `id`
- `plan_id`
- `session_template_id`
- `key`
- `name`
- `pool_id`
- `count`
- `optional`
- `rules`
- `position`
- timestamps

Use JSON/JSONB for:

- `rules`

Validations:

- session template and pool must belong to same plan.
- `count` must be greater than zero.
- `position` should be stable.

---

### DirectGoal

A scheduled target that does not require a session wrapper.

Examples:

- Read 20 minutes every day
- Record bodyweight every morning
- Take a scheduled dose
- Walk 5000 steps

Required fields:

- `id`
- `plan_id`
- `key`
- `name`
- `description`
- `event_type_id`
- `target`
- `completion_policy`
- `missed_policy`
- timestamps

Use JSON/JSONB for:

- `target`
- `completion_policy`
- `missed_policy`

Relationships:

- belongs to Plan
- belongs to EventType
- has one or more Schedules

This can be minimal in the first pass if the gym/vial scenarios do not require direct goals.

---

### Schedule

Shared scheduling vocabulary for session templates and direct goals.

Required fields:

- `id`
- `plan_id`
- `owner_type`
- `owner_id`
- `kind`
- `rules`
- `start_date`
- `end_date`
- timestamps

Suggested `kind` values:

- `every_day`
- `selected_weekdays`
- `every_n_days`
- `times_per_week`
- `after_completion`
- `custom`

Use JSON/JSONB for:

- `rules`

Examples:

```json
{
  "weekdays": ["monday", "wednesday", "friday"]
}
```

```json
{
  "times": 3,
  "allowed_weekdays": ["monday", "wednesday", "friday", "saturday"],
  "minimum_gap_days": 1
}
```

For the first POC, implement only enough scheduling to support:

- selected weekdays
- times per week with simple deterministic placement

The planner must return diagnostics for unsupported or impossible schedules.

---

### SessionOccurrence

One actual planned or completed instance of a session.

Required fields:

- `id`
- `plan_id`
- `session_template_id`
- `planned_for`
- `status`
- `recommendation_snapshot`
- `started_at`
- `completed_at`
- `feedback`
- `notes`
- timestamps

Suggested `status` values:

- `planned`
- `started`
- `completed`
- `missed`
- `skipped`
- `partially_completed`

Use JSON/JSONB for:

- `recommendation_snapshot`
- `feedback`

Relationships:

- belongs to Plan
- belongs to SessionTemplate
- has many SlotResults
- has many EventInstances

Actions:

- create_projected
- start
- complete
- mark_skipped
- mark_missed
- get_context

Notes:

- Projection should not automatically create occurrences unless the action explicitly asks to persist projected occurrences.
- For the POC, it is acceptable to create an occurrence when starting a projected session.

---

### SlotResult

Records how a slot played out inside one occurrence.

Required fields:

- `id`
- `plan_id`
- `session_occurrence_id`
- `session_slot_id`
- `recommended_item_id`
- `actual_item_id`
- `status`
- `event_instance_id`
- `notes`
- timestamps

Suggested `status` values:

- `planned`
- `completed`
- `skipped`
- `partially_completed`
- `swapped`

Relationships:

- belongs to Plan
- belongs to SessionOccurrence
- belongs to SessionSlot
- optionally belongs to recommended Item
- optionally belongs to actual Item
- optionally belongs to EventInstance

Validations:

- all linked records must belong to same plan.

---

### EventInstance

The user-facing journal event.

This is a domain model and must not be replaced by AshEvents.

Required fields:

- `id`
- `plan_id`
- `event_type_id`
- `session_occurrence_id`
- `slot_result_id`
- `direct_goal_id`
- `effective_at`
- `recorded_at`
- `summary`
- `quantity`
- `unit`
- `payload`
- `note`
- `status`
- `origin`
- `voided_at`
- `replaces_event_instance_id`
- timestamps

Suggested `status` values:

- `active`
- `voided`
- `corrected`

Suggested `origin` values:

- `manual`
- `seed`
- `assistant_proposed`
- `imported`
- `offline_sync`

Use JSON/JSONB for:

- `payload`

Relationships:

- belongs to Plan
- belongs to EventType
- optionally belongs to SessionOccurrence
- optionally belongs to SlotResult
- optionally belongs to DirectGoal
- has many EventItemLinks
- has many ItemEffects

Actions:

- log
- correct
- void
- read_journal
- get_recent_for_plan
- get_recent_for_item

Important behavior:

- `recorded_at` is when the app received the log.
- `effective_at` is when the thing happened.
- Event edits should not silently mutate old effects.
- Correcting an event should void the old event/effects and create a replacement event/effects.
- Deleting should be modeled as void/archive, not physical deletion.

---

### EventItemLink

Connects an event to the items involved, with a role.

Examples:

- `exercise`: Chest Press
- `machine`: Bike
- `source_vial`: Retatrutide vial 1
- `environment`: JD Gym

Required fields:

- `id`
- `plan_id`
- `event_instance_id`
- `item_id`
- `role`
- `metadata`
- timestamps

Use JSON/JSONB for:

- `metadata`

Validations:

- event and item must belong to same plan.
- required roles from EventType should be present when logging.

---

### ItemEffect

A state change caused by an event.

Examples:

- subtract 250 mcg from a vial
- add 10 units to a supply
- set current page for a book
- inventory correction

Required fields:

- `id`
- `plan_id`
- `item_id`
- `event_instance_id`
- `effect_type`
- `quantity`
- `unit`
- `payload`
- `status`
- `voided_at`
- `replaces_item_effect_id`
- timestamps

Suggested `effect_type` values:

- `add_quantity`
- `subtract_quantity`
- `set_quantity`
- `set_fact`
- `correction`

Suggested `status` values:

- `active`
- `voided`

Use JSON/JSONB for:

- `payload`

Important behavior:

- Current item state is derived from item starting facts plus active effects.
- Voided effects do not contribute to current state.
- Effects should be generated from EventType effect rules where practical.
- Manual effect creation should be avoided except in tests/fixtures.

---

## Pure Planning Package

The planning package is the deterministic brain of the app.

It must live in plain Elixir modules, not inside Ash DSL blocks.

It may receive structs, maps, or purpose-built input structs.

It must not:

- Read from the database.
- Call LLMs.
- Send emails.
- Read wall-clock time.
- Talk to the network.
- Mutate journal history.
- Randomly choose outcomes without an explicit seed or deterministic rule.

Suggested modules:

```text
Improve.Planning.Input
Improve.Planning.Output
Improve.Planning.Projector
Improve.Planning.Recommender
Improve.Planning.Diagnostics
Improve.Planning.ItemState
```

### Projector

Inputs:

- user
- active plans
- session templates
- direct goals
- schedules
- targets
- policies
- items
- pools
- environments
- event history
- item state
- date window

Outputs:

- projected session occurrences
- projected direct goal targets
- target statuses
- recommended items
- diagnostics
- explanations
- policy proposals
- state warnings

Projection must not mutate history.

### Recommender

For session slots, choose recommended items based on:

- pool membership
- environment availability
- recent usage
- prior swaps
- item state
- slot rules
- stable deterministic ordering

For the POC, keep this simple:

1. Filter items by pool.
2. Filter by environment if implemented.
3. Avoid archived items.
4. Prefer least recently used item.
5. Use stable key/name ordering as tie-breaker.

### ItemState

Calculate current state for stateful items.

For a vial:

```text
current_quantity = starting_quantity + sum(active item effects)
```

Support:

- add quantity
- subtract quantity
- set quantity/correction

Return:

- starting facts
- active effects
- calculated state
- warnings

Example warning:

- item quantity is below configured threshold
- item quantity will be insufficient for projected future dose

---

## Required Scenario Tests

The tests are the UI for this POC. They should read like product stories.

### 1. Gym Plan Installation

Test:

```text
Given a demo user
When the gym demo plan is installed
Then the plan contains:
  - item types for Exercise, Cardio Machine, Gym Environment
  - items including Chest Press, Shoulder Press, Lat Pulldown, Seated Row, Bike, Rower, JD Gym
  - pools for Push, Pull, Cardio
  - an Upper-biased gym visit session template
  - slots: 2 from Push, 2 from Pull, 1 from Cardio
  - a schedule for 2 or 3 sessions per week
```

Acceptance:

- data persists in Postgres
- references are valid
- no orphaned rows
- plan summary action returns useful counts

---

### 2. Project Today for Gym Plan

Test:

```text
Given an active gym plan
And today is inside the plan date range
When project_today is called with an explicit date
Then the planner returns a projected session occurrence
And the occurrence includes recommended slot items
And no database mutation occurs unless explicitly requested
```

Acceptance:

- output contains session template name
- output contains slot recommendations
- output contains diagnostics array, even if empty
- output contains explanations suitable for future assistant context

---

### 3. Start Gym Session and Swap Item

Test:

```text
Given a projected Upper-biased gym visit
When the user starts the session
And the app recommends Rower for cardio
And the user chooses Bike instead
Then a persisted SessionOccurrence exists
And a SlotResult records recommended_item = Rower
And actual_item = Bike
And status = swapped or completed
```

Acceptance:

- occurrence belongs to the user's plan
- slot result preserves both recommendation and actual choice
- swap is queryable later

---

### 4. Log Workout Events and Complete Session

Test:

```text
Given a started gym session
When the user logs:
  - Chest Press, 3 sets of 10 at 45 kg, RPE 8
  - Lat Pulldown, 3 sets of 10 at 50 kg, RPE 8
  - Bike, 20 minutes, moderate effort
Then EventInstances are created
And EventItemLinks connect each event to the relevant item
And SlotResults link to the matching events
When the session is completed
Then the SessionOccurrence status is completed
```

Acceptance:

- journal read action returns the events in effective time order
- item history for Chest Press includes the event
- session context includes planned/recommended/actual values

---

### 5. Vial Plan Installation

Test:

```text
Given a demo user
When the vial demo plan is installed
Then the plan contains:
  - item type Peptide Vial
  - item Retatrutide vial 1
  - event type Take Dose
  - Take Dose has source_vial item link role
  - Take Dose has effect rule subtracting amount from source vial
```

Acceptance:

- vial item has starting quantity facts
- event type effect rule validates against item link roles

---

### 6. Dose Event Creates Item Effect

Test:

```text
Given Retatrutide vial 1 has starting quantity 5000 mcg
When the user logs Take Dose:
  - amount: 250
  - unit: mcg
  - source_vial: Retatrutide vial 1
Then an EventInstance is created
And an EventItemLink connects role source_vial to the vial
And an ItemEffect subtracts 250 mcg
And get_item_state returns remaining quantity 4750 mcg
```

Acceptance:

- effect is active
- event is active
- state is derived, not manually overwritten

---

### 7. Correcting Dose Voids and Replaces Effects

Test:

```text
Given a dose event subtracted 250 mcg
When the user corrects the event to 300 mcg
Then the original event is marked corrected or voided
And the original item effect is voided
And a replacement event is created
And a replacement item effect subtracts 300 mcg
And get_item_state returns remaining quantity 4700 mcg
```

Acceptance:

- old effect no longer contributes to state
- replacement relationship is stored
- journal can show correction history
- no physical deletion is required

---

### 8. Invalid Plan Diagnostics

Test:

```text
Given a malformed plan draft where a session slot references a missing pool
When validation runs
Then the system returns a plain-English diagnostic:
  "This session slot points at a pool that does not exist."
```

Acceptance:

- validation does not crash
- diagnostic includes path/key information where practical
- diagnostic can be shown to a user or bundle author

---

### 9. AshTypescript Contract Smoke Test

Test:

```text
When TypeScript generation runs
Then generated output includes types/actions for:
  - Plan
  - Item
  - EventInstance
  - ItemEffect
  - SessionOccurrence
And generated action input names are understandable
```

Acceptance:

- generated files are committed or produced in a documented path
- include a short note in the README explaining how to regenerate them
- optionally compile a tiny TypeScript file that imports representative generated types

No React app is required.

---

### 10. AshAI Read Tool Smoke Test

Expose read-only tools for:

- project today's work
- get plan summary
- get recent journal events
- get item state

Test:

```text
Given a seeded gym plan and vial plan
When the AI tool layer asks for today's projection
Then the tool returns structured data from Ash actions/planning output
When the AI tool layer asks for vial state
Then the tool returns the derived state
```

Acceptance:

- tools reuse normal domain actions where practical
- tools do not bypass policies/validations
- no important writes are allowed directly through AI tools in this POC

Optional:

- add a `propose_event_log` action that creates an approval/proposal record
- do not implement full approval UI

---

## Optional AshEvents Experiment

If simple, configure AshEvents to record resource mutations for selected resources.

Use it for infrastructure audit/change history only.

Do not use AshEvents as the product journal.

Suggested resources to audit:

- Plan
- Item
- EventInstance
- ItemEffect
- SessionOccurrence

Acceptance:

- creating/correcting an event produces useful audit entries
- audit entries include actor where possible
- removing AshEvents would not break the product journal model

If AshEvents creates too much friction, document the friction and skip it.

---

## Policies and Ownership

Even without real auth, model actor ownership.

Each action should receive an actor where practical.

Implement basic policies:

- users can only read/write their own plans
- users can only read/write records belonging to their own plans
- test that cross-user access fails

Admin policies are not required.

Impersonation is not required.

Billing entitlement checks are not required.

---

## Transactions

Important workflows should be atomic.

Required transactional behaviors:

### Installing a demo plan

Either all plan records are created or none are.

### Logging an event

The following should happen in one transaction:

- create EventInstance
- create EventItemLinks
- validate required roles
- create ItemEffects from effect rules
- update SlotResult link/status if applicable

### Correcting an event

The following should happen in one transaction:

- void/correct old EventInstance
- void old ItemEffects
- create replacement EventInstance
- create replacement EventItemLinks
- create replacement ItemEffects

If a transaction becomes awkward in Ash DSL alone, use plain Elixir orchestration that calls Ash actions. Clarity is more important than forcing everything into DSL blocks.

---

## Validation and Diagnostics

The POC must show that invalid authored content can produce useful diagnostics.

Diagnostics should be plain English and should avoid cryptic internal errors.

Required diagnostic cases:

- duplicate keys within a plan
- missing pool referenced by session slot
- missing item type referenced by event item role
- effect rule references missing item link role
- invalid schedule kind
- unsupported schedule rule
- dose event missing required source vial
- dose event quantity incompatible with effect rule

Suggested diagnostic shape:

```elixir
%{
  severity: :error | :warning,
  code: "missing_pool",
  message: "This session slot points at a pool that does not exist.",
  path: ["session_templates", "upper", "slots", "cardio"],
  ref: "cardio"
}
```

---

## Demo Fixtures

### Gym Plan Fixture

Create one active plan:

```text
Name: General Fitness
Intention: Build consistent gym progress
Date range: today through today + 8 weeks
```

Item types:

- Exercise
- Cardio Machine
- Gym Environment

Items:

- Chest Press
- Shoulder Press
- Cable Fly
- Lat Pulldown
- Seated Row
- Bike
- Rower
- JD Gym

Pools:

- Push: Chest Press, Shoulder Press, Cable Fly
- Pull: Lat Pulldown, Seated Row
- Cardio: Bike, Rower

Environment:

- JD Gym

Session template:

```text
Upper-biased gym visit
Schedule: 2 or 3 times per week
Environment: JD Gym
Slots:
  - 2 from Push
  - 2 from Pull
  - 1 from Cardio
```

Event types:

- Workout exercise performed
- Cardio block performed

Workout payload example:

```json
{
  "sets": 3,
  "reps": 10,
  "load": 45,
  "load_unit": "kg",
  "rpe": 8
}
```

Cardio payload example:

```json
{
  "duration_minutes": 20,
  "intensity": "moderate"
}
```

---

### Vial Inventory Fixture

Create one active plan:

```text
Name: Retatrutide Inventory
Intention: Track vial quantity and dose history
Date range: today through today + 12 weeks
```

Item types:

- Peptide Vial
- Injection Site

Items:

```text
Retatrutide vial 1
  compound: Retatrutide
  starting_quantity: 5000
  unit: mcg
  prepared_volume: 2
  prepared_volume_unit: ml
  concentration: 2500
  concentration_unit: mcg_per_ml
  low_quantity_threshold: 500
```

```text
Abdomen
  type: injection site
```

Event type:

```text
Take Dose
```

Payload schema should support:

- amount
- unit
- route
- site
- subjective_feedback
- notes

Item link roles:

- source_vial, required
- site, optional

Effect rule:

- subtract `payload.amount` `payload.unit` from linked item role `source_vial`

---

## README Requirements

Write a README that explains:

- what this POC is
- what it intentionally excludes
- how to set up Postgres
- how to run migrations
- how to run tests
- how to seed demo data
- how to open IEx and call key actions
- how to regenerate TypeScript output
- what AshAI tools exist
- what is still unresolved

Include a short "POC verdict checklist" with these questions:

```text
1. Are the resources/actions easier to understand than the Go/sqlc version?
2. Are the hard workflows smaller?
3. Are transaction boundaries clear?
4. Are errors and diagnostics understandable?
5. Does generated TypeScript look good enough for a future React/shadcn app?
6. Do AshAI tools feel naturally derived from domain actions?
7. Is debugging acceptable?
8. Would we be comfortable building the real product on this?
```

---

## Success Criteria

The POC is successful if:

- A developer can install the app, run migrations, run tests, and seed demo data.
- The gym scenario works end-to-end with session projection, recommendation, swap, event logging, and completion.
- The vial scenario works end-to-end with dose logging, item effect generation, derived state, and correction.
- The planning package remains pure and easy to test.
- The Ash resources/actions read like the product model rather than framework noise.
- Generated TypeScript contracts look usable for a future React app.
- AshAI can expose useful read-only tools without bespoke glue everywhere.
- Cross-user ownership checks exist and pass.
- Invalid plan content returns plain-English diagnostics.
- No UI was required to prove the core model.

The POC is not successful if:

- The implementation feels more magical and less debuggable than Go/sqlc.
- Transactional workflows are hard to reason about.
- Domain behavior is scattered across too many Ash DSL hooks.
- Generated TypeScript is awkward or misleading.
- The planner becomes coupled to database access or Ash internals.
- The model only works for the happy path.

---

## Implementation Advice for the Agent

Prefer boring clarity over clever DSL gymnastics.

Use Ash where it helps:

- resource modeling
- actions
- policies
- validations
- relationship loading
- code interfaces
- typed contracts
- extension integration

Use plain Elixir where it is clearer:

- deterministic projection
- recommendation rules
- item state calculation
- multi-step orchestration
- import/fixture installation
- diagnostics over authored JSON

Keep action names product-oriented.

Good examples:

```text
install_gym_demo_plan
project_today
start_session
record_slot_result
log_event
correct_event
get_item_state
get_recent_journal
```

Avoid generic names when behavior matters.

Do not prematurely build a generic everything engine. The POC only needs enough generality to prove that gym, vial inventory, and future domains can share the same underlying shape.

---

## Suggested Build Order

1. Create Phoenix/Ash app with Postgres.
2. Add User and Plan.
3. Add ItemType, Item, Pool, PoolMembership, Environment.
4. Add EventType, EventInstance, EventItemLink, ItemEffect.
5. Implement item state calculator.
6. Add gym fixture installer.
7. Add vial fixture installer.
8. Add SessionTemplate, SessionSlot, SessionOccurrence, SlotResult.
9. Implement simple planning projector/recommender.
10. Add event logging transaction.
11. Add event correction transaction.
12. Add diagnostics module.
13. Add scenario tests.
14. Add AshTypescript generation.
15. Add AshAI read-only tools.
16. Optionally add AshEvents audit experiment.
17. Write README and POC verdict notes.

---

## Final Deliverables

The agent should deliver:

- Working source code.
- Migrations.
- Seeds/fixtures.
- ExUnit scenario tests.
- Generated TypeScript output or documented generation command.
- AshAI tool smoke test.
- README.
- Short implementation notes covering:
  - what worked well
  - what felt awkward
  - where Ash reduced boilerplate
  - where plain Elixir was better
  - whether this feels smaller/cleaner than the Go/sqlc approach

Do not deliver a UI.
Do not deliver admin.
Do not deliver billing.
Do not deliver a production-ready app.

Deliver a clear headless Ash kernel that proves or disproves the architectural bet.
