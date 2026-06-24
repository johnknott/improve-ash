# Improve Model And Extension Points

Draft date: 2026-06-24.

## 1. What Improve Is

Improve is an app for helping a person work on themselves over time.

It is not just a habit tracker, workout logger, inventory tracker, journal, or
calendar. It borrows pieces from all of those, but the real product idea is
broader:

- describe what you are trying to improve
- define the work, measurements, practices, supplies, and routines involved
- ask the app what matters today
- do the work, or do something different
- record what actually happened
- correct mistakes without losing history
- derive useful state from that history
- review the plan and make it better

The core product loop is:

```text
plan -> projection -> recommendation -> action -> journal -> state -> review
```

The app should feel plain-English to users. They should not need to understand
database tables, effect internals, payload paths, or programming concepts just
to make a normal plan.

## 1b. Why We Are Building The Backend First

We are building the backend first because the model is the hard part.

Before we design the final browser UI, we want to prove that the product can be
expressed cleanly in code:

```elixir
create a plan
add tracks
add sessions
choose items from pools
project today
start a session
log what happened
correct a mistake
derive item state
review the plan
```

Executable stories are our rehearsal space for that.

A story is a small Elixir script that uses the same headless product API the UI
will eventually use. If a story reads awkwardly, that is a useful signal. It
means the API, vocabulary, or model is not ready yet.

The current backend work is therefore not just "implementation". It is product
model discovery. The stories let a nice API emerge before UI screens freeze the
wrong concepts in place.

## 1c. Build Order

The intended build order is:

1. Backend product kernel.
2. Executable product stories and tests.
3. Browser web app.
4. Flutter mobile apps.

The web app should not invent separate business logic. It should call the same
backend/product API proven by stories.

The Flutter apps should come after that, once the backend model and browser
flows are clearer.

## 2. Current Model In Plain English

This section explains the current model as product concepts, not database
implementation details.

### Users And Plans

A user owns plans.

A plan is a dated intention. It says, roughly:

```text
From this date to that date, I am trying to improve something.
```

A plan can contain tracks, sessions, items, pools, environments, event types,
schedules, journal events, and derived state.

### Tracks

A track is something the user wants to do, measure, improve, or remember.

Examples:

- Read 20 pages.
- Walk 8,000 steps.
- Weigh myself.
- Drink water.
- Practice piano.
- Take inventory.

A track can have:

- a name
- a stable key
- a target
- a schedule
- an event type used when logging it
- completion rules
- missed-work rules

Right now, tracks are the main product-facing replacement for the old
DirectGoal idea.

### Targets

A target describes what "good" looks like for a track.

Examples:

- fixed amount: `20 pages`
- metric: `bodyweight in kg`
- checklist: `tidy room, brush teeth`
- progression: `1,000 steps toward 10,000 steps`
- adaptive: `suggest sets/reps/load from history`

The system can store several target shapes already. It can evaluate simple
fixed targets cleanly today. More complex target shapes exist mostly as
authored vocabulary and diagnostics; many do not yet have complete evaluation
logic.

### Schedules

A schedule says when a track or session should appear.

Current simple shapes include:

- every day
- selected weekdays
- every N days
- N times per week
- every N weeks
- monthly
- after completion
- custom descriptions

Projection uses schedules to decide what should appear for a specific date.

### Items

An item is a thing a plan can choose, use, track, or affect.

Examples:

- an exercise
- a book
- a piano drill
- a supply container
- a medication vial
- a project
- a location-specific option

Items can have item types. Item types let the plan say "these are practice
items" or "these are supply containers" without hard-coding domain-specific
concepts into the app.

Items can also have starting facts, such as:

```text
starting quantity: 20
unit: uses
low quantity warning: 5
```

### Pools

A pool is a named group of items to choose from.

Examples:

- Technique choices
- Push exercises
- Listening drills
- Available supplies

Pools are especially useful in sessions. A session slot can say:

```text
choose 2 items from this pool
```

### Environments

An environment is a place or context that may affect what makes sense.

Examples:

- home
- gym
- travel
- office

The model has room for environments, but the current recommendation logic only
uses them lightly. Rich environment-aware recommendations are future work.

### Sessions

A session is a group of work that happens together.

Examples:

- Focused practice
- Upper body gym visit
- Sunday review
- Cleaning session

A session template describes the intended shape of the session.

A session contains slots.

### Slots

A slot is one part of a session.

Examples:

- choose 2 technique items
- choose 1 push exercise
- choose 1 listening drill

A slot can point at a pool, ask for a number of items, and contain rules for
recommendations.

When the app projects a session for today, it recommends items for each slot.

### Recommendations And Actuals

The app separates what it recommended from what the user actually did.

That matters because real life is messy.

For example:

```text
Recommended: Sight reading
Actual: Improvisation
```

The system preserves both. This lets review logic learn from swaps instead of
pretending the recommendation was always correct.

### Session Occurrences And Slot Results

A projected session is just a proposal until the user starts it.

When the user starts a session, the system creates a session occurrence.

The session occurrence records:

- which session template it came from
- what date it was planned for
- whether it is started, completed, partial, or skipped

Slot results preserve the recommendation and the actual result for each slot.

A slot result can represent:

- completed as recommended
- swapped to a different item
- skipped
- still open

### Event Types

An event type describes a kind of thing that can be logged.

Examples:

- Pages read
- Practice logged
- Use recorded
- Dose taken
- Metric logged

An event type can define:

- expected payload fields
- item link roles
- effect rules

For example, an event type might say:

```text
This event requires a linked item with role "container".
When logged, subtract payload.amount from that container.
```

### Events

An event is the user-facing journal record of what actually happened.

Examples:

- Read 25 pages.
- Practiced piano scales.
- Used 3 units from the workshop bin.
- Corrected a previous entry.

Events are durable history. We should not casually rewrite them.

Corrections preserve history by marking old records corrected and creating
replacement records.

### Event Item Links

An event item link connects an event to an item with a role.

Examples:

```text
event: Use recorded
role: container
item: Workshop bin
```

or:

```text
event: Practice logged
role: item
item: Piano scales
```

This lets one generic event system handle many domains without adding
domain-specific verbs to the core.

### Effects

An effect is a typed change to item state caused by an event.

Current effect types include:

- add quantity
- subtract quantity
- set quantity
- set fact
- correction

Effects are not the source of truth by themselves. They are derived from
journal events and effect rules.

The important idea is:

```text
starting item facts + active effects = current item state
```

That gives us an auditable way to answer questions like:

```text
How much is left?
What facts currently apply?
Which warnings should be shown?
```

### Derived Item State

Item state is calculated, not manually edited.

For example, if an item starts with 20 uses and the journal contains one active
effect subtracting 17 uses, the current quantity is 3 uses.

If that event is corrected, the old effect is voided and a replacement effect
is created. The current state is recalculated from active effects only.

### Projection

Projection asks:

```text
What should this plan show for this date?
```

Projection should not mutate journal history.

It reads the plan, schedules, sessions, tracks, items, pools, journal events,
session occurrences, and slot results. It returns planned work, statuses,
recommendations, explanations, and diagnostics.

### Review

Review is a deterministic read over the plan and history.

Right now it can produce simple observations and suggested changes, such as:

- there is no history yet
- there is still work open today
- diagnostics should be reviewed
- history exists and may be useful for tuning recommendations

Review does not call an LLM and does not write product data.

### AI Context

The current AI layer is read-only.

It exposes structured context that an assistant could use, such as:

- plan summary
- projected work
- recent journal events
- item state

AI tools should not become a second business-rule engine.

## 3. What The System Can And Cannot Do Cleanly Today

### What It Can Do Cleanly

The system can cleanly handle simple product loops:

- create plans
- add tracks
- add item types and items
- group items into pools
- add simple schedules
- project today's tracks and sessions
- start a projected session
- preserve recommendations
- log actual session results
- represent swaps and skips
- log track completions
- log generic events
- link events to items
- generate typed item effects from events
- derive item state from starting facts plus active effects
- correct mistakes without deleting history
- accept offline entries with idempotency and conflict handling
- return plain-English diagnostics for many authoring mistakes
- expose read-only AI context
- run backend product stories as executable checks

The model is strongest when the user's intention can be represented as:

```text
On this schedule, do or log this thing, maybe choosing items from a pool.
When an event happens, record it and maybe apply typed effects to linked items.
```

### What It Can Store, But Not Fully Understand Yet

Some shapes can be authored, stored, or partially projected, but not evaluated
deeply yet:

- metric targets
- checklist targets
- period totals
- progressions
- adaptive targets
- custom schedules
- environment-aware recommendations
- review-driven adjustments

These are useful vocabulary, but the system does not yet have a complete
general engine for deciding whether every complex target is met or what should
happen next.

### What It Struggles With Today

The system struggles with rolling, conditional, aggregate, or programmatic
logic.

Examples:

- average 8,000 steps over the last 7 days
- read 100 pages per week with surplus carryover
- meditate 5 days in a row
- do this at least 80 percent of days
- keep sleep between 7 and 9 hours
- drink no more than 2 coffees per day
- avoid alcohol this week
- protein per kg of bodyweight
- training volume per muscle group
- sleep debt
- readiness score
- only schedule running if knee pain is below 3
- reduce workout volume if sleep was poor
- choose from items available in this environment
- avoid repeating the same movement pattern within 48 hours
- add weight after successful sessions
- deload after repeated failures
- run a four-week training block with different phases
- split consumption across multiple containers
- use the oldest batch first
- reserve quantity for planned future use
- convert between units automatically

These are not impossible product ideas. They are just not cleanly represented
by the small core yet.

### The Current Boundary

The current core is good at durable facts:

```text
what exists
what was planned
what was recommended
what actually happened
what state changed
what current state is derived from history
```

It is less good at flexible decision logic:

```text
what counts
what is enough
which rule wins
what should adapt
what should be recommended next
what should be scheduled under changing conditions
```

That suggests the core should stay small, but the decision points should become
explicit extension points.

## 4. Open Question: How Should We Represent This More Cleanly?

We want to fill the gaps without turning the core model into a giant pile of
special cases.

The direction we are considering is:

```text
small stable core + safe extension points + bundles
```

The core would continue to own:

- users
- plans
- tracks
- sessions
- items
- pools
- events
- item links
- item effects
- derived state
- authorization
- validation
- journal writes
- correction history
- transactions

Extensions would not directly mutate the journal or bypass the model.

Instead, extensions would receive explicit input and return explicit output.

Possible extension points:

- target evaluation
- schedule projection
- session recommendation
- item filtering
- effect generation
- derived metric calculation
- review analysis
- diagnostics
- suggested plan changes

For example, a projection/scheduling extension point might receive everything it
needs:

```text
plan
tracks
sessions
schedules
items
pools
environments
journal history
item state
date being projected
```

and return:

```text
proposed work for the date
recommendations
explanations
diagnostics
```

The extension would not write events. It would not start sessions. It would not
change state. It would only propose.

The core would still decide how to validate, display, persist, or reject the
result.

### Built-In Systems Should Dogfood The Same Extension Points

We should not create extension points only for future power users.

Our own built-in systems should use them too.

Examples:

- fixed target evaluator
- range target evaluator
- rolling total evaluator
- every-day schedule projector
- weekly quota projector
- avoid-recent recommendation strategy
- history-based recommendation strategy
- low-inventory review analyzer
- subtract-quantity effect generator

That gives us a test of the extension contracts before exposing them to users.

If our built-ins cannot be expressed cleanly through the extension points, the
extension points are probably wrong.

### Safe User Logic

Eventually, power users and advanced bundles might use a safe language such as
Starlark.

The goal would not be to let arbitrary code control the app.

The goal would be to let advanced logic answer bounded questions:

```text
Does this target count as complete?
Is this schedule due today?
Which item should be recommended?
Should this effect apply?
What derived metric value should be returned?
What review observation should be shown?
```

The safe language should have:

- no arbitrary database access
- no network access
- no hidden clock access
- no mutation of journal history
- no direct writes
- explicit inputs
- explicit outputs
- time limits
- clear diagnostics

### The Question

How could we represent the model more cleanly so that:

- simple users get built-in systems that feel obvious
- advanced users can express richer logic safely
- our own complex features are built as bundles on the same extension points
- the core remains small, durable, auditable, and boring
- projection, scheduling, recommendations, effects, metrics, and review can
  become much more flexible without turning into hidden business logic

That is the design problem to solve next.

## 5. Planned: Time-Off Windows

A time-off window is a planned span during which the user is unavailable, or
only partially available - a holiday, travel, a busy period, or planned rest.
It is distinct from a journal event: a journal event records what happened,
while a time-off window declares a constraint on what should be scheduled. Both
can cover the same dates without conflict.

This matters for adaptive plans. A two-week holiday mid-training is a common
case, and handling it well is part of what makes a plan genuinely adaptive
rather than static.

### Shape

A time-off window is plan-scoped:

- `key`: a stable, plan-unique identifier
- `from_date` / `to_date`: an inclusive date range
- `kind`: `holiday`, `travel`, `sick`, or similar
- `availability`: `fully_off` (the default) or `limited`
- `note`

It belongs to a plan. It is not a schedule (it is negative space - when not to
schedule) and not an event (it is intent, not history).

### How Projection Treats It

A `fully_off` window occludes scheduled work. Tracks and sessions that fall
inside the range are suppressed and shown as on hold - importantly, they are
not marked missed. Blocking dates on the calendar should mean the plan respects
them, not that the user falls behind.

A `limited` window is left to the adaptation evaluator, because "what is still
doable while travelling" is domain-specific. A marathon plan might keep easy
hotel runs; a reading plan might be unaffected. Core projection handles only
the simple universal case; richer judgement lives in the evaluator.

### How Adaptation Treats It

The adaptation evaluator reads time-off windows alongside history and derived
load, and proposes how to recover:

- During a `limited` window: a maintenance version of the work (derived, no
  write).
- After any window: a gentler re-entry or rebuild, since fitness is lost
  (derived, no write).
- To absorb the gap: extend the plan, insert a rebuild block, or shift the
  schedule (committed - these mutate plan structure, so they surface for
  approval and the core writes them).

### The Immovable Deadline

Committed proposals like extending assume the plan's end date can move. Often
it cannot: a marathon is a fixed external event. When the deadline is
immovable, the evaluator shifts from "extend" to "compress the taper" or
"adjust the goal" (for example, target sub-4:00 becomes finish). The deadline
is just the plan's end date, supplied as input; whether it can move is domain
judgement the evaluator owns.

This is why time-off handling cannot be a hardcoded rule. The right answer
depends on the kind of plan, where the window falls, and whether the deadline
is soft or hard.
