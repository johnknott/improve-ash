# Plain-English Product Story Scripts

Draft date: 2026-06-23.

## Purpose

We want a small set of executable Elixir scripts that exercise Improve like a
user would.

These scripts are not normal tests, and they are not a CLI. They are executable
product stories. Each script should describe one common user flow in clear,
plain Elixir, while calling the same headless domains and workflow functions the
future UI will call.

The scripts should help us answer:

- Can a common UI flow be expressed simply?
- Are the product nouns right?
- Are the product verbs right?
- Does the API preserve the difference between planned, recommended, actual,
  logged, corrected, and derived state?
- Does the AI layer receive useful structured context?

If a script feels awkward, that is useful. It means the app-facing API may need
better names, better defaults, or a friendlier workflow layer.

## Location

Story scripts live under:

```text
priv/scripts/stories/
```

Run a story with:

```sh
mix run priv/scripts/stories/01_direct_goal_reading.exs
```

Current scripts:

```text
priv/scripts/stories/01_direct_goal_reading.exs
priv/scripts/stories/02_start_and_log_gym_session.exs
priv/scripts/stories/03_log_dose_and_check_vial_state.exs
```

Possible future scripts:

```text
priv/scripts/stories/04_project_today.exs
priv/scripts/stories/05_log_direct_goal.exs
priv/scripts/stories/06_correct_logged_event.exs
priv/scripts/stories/07_submit_offline_batch.exs
priv/scripts/stories/08_ai_today_context.exs
```

Story runs quiet SQL/debug logs by default so the product output stays readable.
Use `--debug` when the database chatter is useful.

Supported modes:

```sh
mix run priv/scripts/stories/02_start_and_log_gym_session.exs --keep
mix run priv/scripts/stories/02_start_and_log_gym_session.exs --debug
mix run priv/scripts/stories/02_start_and_log_gym_session.exs --rollback
```

`--rollback` is still a placeholder. It currently announces that it is not
implemented and then runs the story normally.

## Core Idea

A story should read like a user journey, not like database setup.

The story helper layer can make scripts readable, but it must remain thin. It
can translate product-friendly calls into existing Ash domain calls, but it
must not contain scheduling logic, recommendation logic, effect interpretation,
or item-state calculation.

The helper layer may:

- Create or find a demo user.
- Reset one story by stable story key.
- Create plans, item types, items, pools, environments, event types, sessions,
  schedules, and direct goals.
- Find records by friendly keys.
- Project today.
- Start sessions.
- Log events.
- Submit offline event batches.
- Read the journal.
- Read item state.
- Call AI read tools.
- Pretty-print output.

The helper layer must not:

- Decide scheduling rules itself.
- Calculate recommendations itself.
- Calculate item state itself.
- Interpret event effects itself.
- Bypass authorization for product workflows.
- Hide product mistakes behind magic.

Reset is the exception: reset is development plumbing, not a product workflow.
It should be scoped by stable story key and should not require a full database
reset for normal iteration.

## Story Layer Versus App API

Treat `Improve.Stories` as a laboratory for discovering the real high-level
application API. It can be friendly, experimental, and script-oriented. It can
own scenario keys, reset behavior, demo users, fixture setup, friendly lookups,
and pretty output.

If a helper describes something the real UI might do, it should eventually move
into an app-facing namespace such as `Improve.App`.

Examples of operations that probably belong in `Improve.App` once their shape
settles:

- create a plan
- project today
- start a session
- log an event
- log a direct goal
- log a session slot
- correct a mistake
- read item state
- submit offline events
- fetch AI context

In the long run, `Improve.Stories` should mostly wrap that app-facing API,
adding story reset, friendly keys, and printing. It should not become the only
pleasant way to use the system.

The intended stack is:

```text
Improve.Plans / Improve.Sessions / Improve.Journal / Improve.Ai
  Core domains, resources, actions, validations, deterministic workflows.

Improve.App
  Product-facing application API used by UI, scripts, specs, and assistant
  orchestration.

Improve.Stories
  Script laboratory: scenario keys, reset, demo users, friendly lookup,
  fixture sugar, and readable output.
```

Promote functions from `Improve.Stories` into `Improve.App` only after stories
show that the operation is real product language rather than temporary script
sugar.

## Scripts And Specs

Readable story scripts and automated story specs should stay close, but not
become the same thing.

A story script is the plain-English walkthrough. It should create a plan,
project today, log what happened, read the journal, check derived state, and ask
what the AI can see. It should optimize for readability and inspection.

A story spec should run the same workflow, or an equivalent workflow using the
same app-facing API, and assert the important outcomes:

- projected work exists
- one event was logged
- duplicate offline retry did not create a second event
- correction voided the old effect and created a replacement
- item state reflects active effects only
- AI context includes the right structured facts

The script protects product readability. The spec protects behavior. Together
they prove the full loop:

```text
plan -> projection -> action -> journal -> derived state -> AI context
```

## Elixir Shape

The ideal product shape reads like this:

```elixir
story =
  Story.begin!("simple_reading_plan", reset?: true)
  |> Story.user!("John", email: "story+reading@example.test")

plan =
  Story.create_plan!(story, "Read more consistently",
    intention: "Read a little every day",
    from: ~D[2026-06-23],
    until: ~D[2026-07-23]
  )

Story.add_event_type!(story, plan, "Pages read",
  key: "pages_read",
  payload: %{
    required: ["pages"],
    properties: %{
      pages: %{type: "integer"},
      note: %{type: "string"}
    }
  }
)

Story.add_direct_goal!(story, plan, "Read 20 pages",
  key: "daily_reading",
  event: "pages_read",
  schedule: Story.every_day(),
  target: %{
    quantity: 20,
    unit: "pages",
    quantity_path: "payload.pages",
    summary_template: "Read %{quantity} %{unit}"
  }
)

today = Story.project_today!(story, plan, on: ~D[2026-06-23])

Story.log_direct_goal!(story, today,
  goal: "daily_reading",
  payload: %{pages: 25, note: "Read before bed"}
)

Story.show_journal!(story, plan)
Story.show_ai_today_context!(story, plan, on: ~D[2026-06-23])
```

The low-level Ash calls are fine inside `Improve.Stories`. They should not
dominate the story scripts themselves.

## Reset Behavior

Every story should have a stable story key:

```elixir
story = Improve.Stories.begin!("daily_reading_goal", reset?: true)
```

Use stable emails and source keys:

```text
email = "story+daily-reading-goal@example.test"
source_key = "story:daily_reading_goal"
```

Default behavior:

```text
Run script
Reset only this story's previous data
Create fresh story data
Print useful output
Keep data for inspection
```

`--keep` can skip the reset. `--rollback` can be added later if it proves useful.

## Product Flows To Cover

Start with a small set of scripts that pressure the core model:

- Create a simple reading plan.
- Add and log a direct goal.
- Create and start a session.
- Log a session slot.
- Log a swap.
- Log inventory state changes.
- Correct a bad event.
- Submit offline events idempotently.
- Show what AI read tools can see.

## Naming Principles

Use product language in the scripts:

```elixir
create_plan!
add_exercise!
add_pool!
add_session!
project_today!
start_session!
log_slot!
log_direct_goal!
log_event!
correct_event!
show_item_state!
show_ai_today_context!
```

Avoid exposing internal mechanics too early:

```elixir
create_session_template_record!
insert_event_instance!
create_pool_membership!
calculate_effect_specs!
```

Those lower-level names can exist inside the implementation. The story script
should read like the product.

## What Good Looks Like

A good story script should be readable by someone who knows the product but not
the database schema.

A good story script should end by reading something back:

- today's projection
- session results
- journal history
- item state
- AI context

A good story script should make awkwardness visible. If three stories need the
same ugly workaround, that is probably a missing app-facing function.

## What To Avoid

Do not build a magical private DSL that hides the real app.

Do not make the scripts so cute that they stop reflecting the UI.

Do not put business rules in story helpers.

Do not make the scripts depend on random generated names unless randomness is
the point of the story.

Do not manually delete rows in every script. Reset by story key instead.

Do not assert exact prose from AI output. Prefer structured context.

## Main Rule

The scripts should be plain enough to read, honest enough to reveal the model,
and close enough to the real UI that improving them improves the product.
