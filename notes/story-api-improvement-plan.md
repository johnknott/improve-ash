# Plain-English Stories And API Improvement Plan

Draft date: 2026-06-24.

## Purpose

Before building the browser UI, the executable stories should prove that the
model can be understood by a normal user.

The goal is not just shorter scripts. The goal is a product-facing API that
reads like the UI we want:

- start a plan
- add tracks
- group some work into sessions
- choose from pools of items
- project today
- start a session
- log what actually happened
- correct mistakes
- derive item state
- review and improve the plan

If a story needs the reader to understand database-ish words, raw JSON schemas,
payload paths, or effect internals too early, the product language is not ready
yet.

## Product Vocabulary

Use these words in stories, UI copy, API names, and diagnostics unless there is
a strong reason not to.

- Plan: a dated intention the user is working on.
- Track: something the user wants to do, measure, improve, or remember.
- Session: a group of work that happens together in a time, place, or context.
- Slot: one part of a session, often choosing one or more items from a pool.
- Item: a thing the plan can choose, use, track, or affect.
- Pool: a named group of items to choose from.
- Environment: a place or context that can limit which items make sense.
- Event: a journal record of what actually happened.
- Effect: a change to item state caused by an event.
- Recommendation: what the app suggests before the user acts.
- Actual: what the user really did.
- Review: a human or AI-assisted pass over history that can suggest changes.

Rename direct goals back to tracks in the product-facing model. "Direct goal"
was useful while splitting the model apart, but it is not friendly enough for
the final UI. A track can be direct, scheduled, session-linked, measured,
checklist-based, adaptive, or state-linked without changing the user's word for
it.

Suggested rename path:

- `DirectGoal` -> `Track`
- `direct_goals` -> `tracks`
- `add_direct_goal!` -> `add_track!`
- `log_direct_goal!` -> `log_track!`
- projected work kind `:direct_goal` -> `:track`
- event field `direct_goal_id` -> `track_id`
- schedule owner type `:direct_goal` -> `:track`

This can be staged. Add public aliases first, rewrite stories, then decide
whether to rename Ash resources and database tables.

## Generic Core

The core API should not contain gym-specific, peptide-specific, medication-
specific, or other domain-specific verbs.

Good core words:

- `add_item_type!`
- `add_item!`
- `add_pool!`
- `add_environment!`
- `add_track!`
- `add_session!`
- `log!`
- `log_track!`
- `start_session!`
- `correct_event!`
- `subtract_quantity`
- `set_quantity`
- `add_quantity`

Avoid core words like:

- `add_exercise!`
- `add_machine!`
- `add_vial!`
- `log_dose!`
- `log_workout!`

Those can exist in templates, fixtures, examples, or user-created plan content,
but not as fundamental app verbs. A user can build a gym plan or stock-tracking
plan with generic primitives.

## Story Principles

A story should read like a user journey, not like database setup.

Stories should prefer:

- friendly helper calls
- track/session/item language
- target constructors
- schedule constructors
- readable logging calls
- output that says what the user would see

Stories should avoid:

- passing `actor:` everywhere
- raw event schema maps in the main happy path
- `direct_goal` naming
- payload paths unless the story is about advanced authoring
- effect rules unless the story is about stateful items
- domain-specific app helpers

The story layer can still wrap the app API with reset, stable users, and pretty
printing. But when a helper describes a real UI operation, promote it into
`Improve.App`.

## Desired Story Shape

The story should be able to read like this:

```elixir
story =
  Story.begin!("reading_track", reset?: true)
  |> Story.user!("John")

plan =
  Story.plan!(story, "Read more consistently",
    intention: "Read a little every day",
    from: ~D[2026-06-23],
    until: ~D[2026-07-23]
  )

Story.track!(story, plan, "Reading",
  schedule: every_day(),
  target: fixed(20, "pages"),
  records: number("pages")
)

today = Story.project_today!(story, plan, on: ~D[2026-06-23])

Story.log_track!(story, today, "Reading",
  amount: 25,
  note: "Read before bed"
)

Story.show_journal!(story, plan)
Story.show_today_context!(story, plan, on: ~D[2026-06-23])
```

The underlying implementation may still create event types, payload schemas,
quantity paths, and journal records. The story should not have to lead with
those details.

## Target API

The rewrite should restore the target types the old app could represent, while
leaving room for the better session/adaptive model.

Suggested constructors:

```elixir
fixed(20, "pages")
metric("Bodyweight", unit: "kg")
checklist(["Tidy room", "Brush teeth"])
period_total(100, "pages", per: :week)
progression(from: 1_000, to: 10_000, unit: "steps", shape: :linear)
adaptive(fields: [:sets, :reps, :load], effort: :rpe, review: :weekly)
```

Target meanings:

- Fixed: each due occurrence asks for the same amount.
- Metric: the user records a value; completion is the act of recording.
- Checklist: the user completes one or more checklist items.
- Period total: progress is accumulated across a week, month, or plan period.
- Progression: the planned amount changes over calendar time.
- Adaptive: the next suggested work depends on item history, feedback, and
  review, not just a fixed calendar line.

Adaptive targets are especially important for session work. A strength machine,
cardio option, study drill, or practice item may need suggestions based on its
own history.

## Adaptive Session Work

The old gym experience revealed a real product need: grouped work and adaptive
item-specific targets.

The generic model should support this flow:

1. The user starts a session.
2. The session has slots.
3. A slot chooses one or more items from a pool.
4. The app recommends an item.
5. The app suggests what to try for that item.
6. The user records what actually happened.
7. The journal preserves recommended versus actual.
8. A review can suggest changes to future recommendations or schedules.

The model should not hard-code "gym", "machine", "sets", or "RPE". Those are
fields a plan can define. But the platform should understand the pattern:

```elixir
Story.track!(story, plan, "Practice item",
  records: fields([:sets, :reps, :load, :effort, :notes]),
  target: adaptive(fields: [:sets, :reps, :load], effort: :effort)
)

Story.session!(story, plan, "Focused practice",
  schedule: every_week(times: 2, on: [:tuesday, :thursday]),
  slots: [
    do_track("Practice item", choose: 2, from: "upper_body_pool")
  ]
)
```

Projected slot recommendations should carry:

- recommended item
- suggested payload
- suggestion reason
- suggestion source, such as history, cold start, coach review, or manual rule
- previous relevant events

Slot results should preserve:

- recommended item
- actual item
- suggested payload
- actual payload
- linked event
- notes
- status

Cold start should also be generic. The plan can ask the user for a comfortable
starting value for whatever fields the track cares about. Later suggestions can
come from history or review.

## Schedule API

The Ash spike currently projects only the simplest useful schedule shapes. The
stories should make the intended schedule vocabulary explicit before UI work.

Suggested constructors:

```elixir
every_day()
selected_weekdays([:monday, :wednesday, :friday])
every_n_days(3)
times_per_week(3, on: [:monday, :wednesday, :friday], minimum_gap_days: 1)
every_n_weeks(2, on: [:saturday])
monthly(day: 15)
after_completion(days: 2)
custom("plain language rule or future expression")
```

The old app supported daily, selected weekdays, every N days, times per week,
every N weeks, and monthly. It had stored vocabulary for after-completion and
custom schedules, but those were not fully projected. The rewrite should at
least tell the truth in stories and diagnostics:

- supported and projected
- recognized but not supported yet
- invalid or ambiguous

Scheduling stories should cover both tracks and sessions, because the same
schedule language should work for both.

## Event Authoring

Users should not start by defining event types.

A simple track should be able to imply a simple event type:

```elixir
Story.track!(story, plan, "Drink water",
  schedule: every_day(),
  target: fixed(3, "litres"),
  records: amount("litres")
)
```

A metric track should imply a metric event:

```elixir
Story.track!(story, plan, "Weight",
  schedule: every_day(),
  target: metric("Weight", unit: "kg")
)
```

Advanced users and plan templates can still define event types directly, but
normal stories should show the friendly path first.

## Stateful Items

Stateful item stories should stay generic. They should prove the model without
embedding one health-adjacent domain into core language.

Preferred story language:

```elixir
Story.item_type!(story, plan, "Container",
  facts: [:starting_quantity, :unit, :low_quantity_threshold]
)

Story.item!(story, plan, "Main container",
  type: "container",
  stateful: true,
  facts: %{starting_quantity: 5000, unit: "units"}
)

Story.event!(story, plan, "Use from container",
  links: [source: "container"],
  records: amount("units"),
  effects: [subtract_quantity(from: "source", quantity: "amount")]
)
```

Templates can later name those things "vial", "dose", "supply", "budget", or
anything else. The core story should prove:

- starting facts
- logged event
- item link
- item effect
- derived state
- correction history
- warnings

## Recommended Story Set

Replace or reorganize the current scripts around product questions.

1. `01_track_reading.exs`
   A simple fixed-amount track. Proves plain track creation, projection,
   logging, journal, and AI context.

2. `02_track_target_types.exs`
   One plan with fixed, metric, checklist, period total, progression, and
   adaptive targets. Proves vocabulary and projection diagnostics.

3. `03_schedule_shapes.exs`
   Daily, selected weekdays, every N days, times per week, every N weeks,
   monthly, after completion, and custom. Proves support status honestly.

4. `04_session_from_pools.exs`
   Generic items, pools, environment, session, slots, recommendations, swaps,
   and session results.

5. `05_adaptive_item_work.exs`
   A session slot recommends an item and a suggested payload from cold start or
   prior history. The user logs actual work, effort, and notes.

6. `06_stateful_item_effects.exs`
   A generic stateful item is changed by events. Proves effects, state, low
   quantity warning, and correction.

7. `07_offline_and_correction.exs`
   Offline retry, duplicate detection, stale session state, and correction.

8. `08_review_and_adjustment.exs`
   A weekly or on-demand review sees journal history and produces proposed
   changes. This can start as structured deterministic output before any LLM is
   involved.

9. `09_full_life_plan.exs`
   A larger plan combining tracks, sessions, item state, schedules, and review.
   This replaces the current translated old-plan rough script once the smaller
   stories read well.

## App API Shape

`Improve.App` should become the friendly API the future UI calls. It can still
delegate to Ash domains and pure planning modules.

Suggested public shape:

```elixir
App.create_plan!(...)

App.add_track!(plan, "Reading", ...)
App.update_track!(track, ...)
App.archive_track!(track, ...)

App.add_session!(plan, "Focused practice", ...)
App.start_session!(today, "focused_practice", ...)
App.log_session_slot!(session, ...)

App.add_item_type!(plan, ...)
App.add_item!(plan, ...)
App.add_pool!(plan, ...)
App.add_environment!(plan, ...)

App.project_today!(plan_or_user, ...)
App.log!(plan, ...)
App.log_track!(today, "Reading", ...)
App.correct_event!(event, ...)

App.get_item_state!(plan, "main_container", ...)
App.review!(plan, ...)
```

The low-level domains remain explicit:

- `Improve.Plans`
- `Improve.Sessions`
- `Improve.Journal`
- `Improve.Planning`
- `Improve.Ai`

But stories, UI code, and assistant orchestration should mostly touch `App`.

## Story API Shape

`Improve.Stories` should remove ceremony from scripts:

- stores the actor
- supplies reset behavior
- uses stable keys
- prints readable output
- wraps `App` without adding business rules

The story API can be even more plain-English than `App`:

```elixir
story = Story.begin!("simple_track") |> Story.user!("John")
plan = Story.plan!(story, "Simple plan", ...)
Story.track!(story, plan, "Reading", ...)
today = Story.today!(story, plan, on: ~D[2026-06-23])
Story.log!(story, today, "Reading", amount: 25)
Story.show!(story, :journal, plan)
```

The script should not need to assign `actor = story.user` unless the story is
explicitly testing lower-level app calls.

## Diagnostics And Output

Story output should use product language.

Prefer:

- "Track: Reading"
- "Session: Focused practice"
- "Recommended: Item A"
- "Actual: Item B"
- "Current quantity: 18 units"
- "This schedule is recognized, but not supported yet."

Avoid:

- "direct_goal"
- "payload"
- "effect rule"
- "owner_type"
- "slot_result_id"
- "resource link"

Those details can appear in debug output, but not in the default story output.

## Acceptance Criteria

This story/API pass is successful when:

- no story uses `direct_goal` in product-facing code or output
- no story uses gym-specific or peptide-specific core API functions
- simple stories do not define raw event schemas
- target types are visible as friendly constructors
- schedule support and gaps are explicit in stories
- session stories preserve planned, recommended, actual, logged, and derived
  state
- adaptive item work can express suggested work, actual work, effort, and notes
- stateful item stories are generic
- AI context reads naturally without requiring AI to operate the product
- a future UI screen can be sketched directly from each story

## Implementation Order

1. Add `track` aliases in `Improve.App`, `Improve.Stories`, projected work, and
   output while keeping existing `DirectGoal` persistence.
2. Add target constructors and rewrite the simple reading story.
3. Add schedule constructors and write the schedule coverage story.
4. Rewrite current story scripts to use `Story.*` wrappers instead of passing
   `actor:` everywhere.
5. Move domain-specific helpers out of `Improve.App` or mark them as fixture
   helpers.
6. Add adaptive target and suggested payload structures to projections.
7. Rewrite session stories around generic pools, slots, recommendations, and
   actual logs.
8. Rewrite stateful item stories with generic names.
9. Once the story language feels right, rename Ash resources and database fields
   if the alias layer still feels like compatibility baggage.

