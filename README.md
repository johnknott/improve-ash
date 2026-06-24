# Improve Ash

Improve Ash is the Phoenix/Ash product codebase for the next version of
Improve.

The current product-language and story/API direction is described in
`notes/story-api-improvement-plan.md`.

The project is still early, but it is now building toward the real product: a
Phoenix API, Ash resources, Postgres persistence, plain Elixir planning
modules, executable product stories, generated TypeScript contracts, read-only
AshAI context tools, and a Svelte UI wired to the backend.

The current scope is intentionally focused on the core Improve loop. This repo
is not building a React UI, LiveView UI, admin section, billing, Stripe
integration, mobile client, or full offline sync system unless that scope is
explicitly expanded.

## Setup

Install the pinned local tools:

```sh
mise install
mise run tools:bootstrap
```

Fetch Mix dependencies:

```sh
mise run deps:get
```

Start local Postgres:

```sh
mise run db:up
```

The development database uses the local Docker Postgres container on host port
`5433`.

## Development

Run the Phoenix server:

```sh
mise run phx:server
```

Or open the zellij dev session:

```sh
mise run dev
```

The dev session starts Postgres first, then opens panes for the Phoenix server,
Svelte/Vite frontend, test watcher, and IEx.

Run the frontend on its own:

```sh
mise run frontend:dev
```

The frontend app lives in `frontend/`. It is a plain Svelte + TypeScript + Vite
app with a basic authenticated app shell, plan switching, demo plan setup, daily
dashboard data, and logging/check-in flows wired through the Phoenix API.

Open a plain IEx session with the app loaded:

```sh
iex -S mix
```

## Database

Common local commands:

```sh
mise run db:create
mise run db:migrate
mise run db:seed
```

`mise run db:reset` drops and recreates local data, so use it deliberately.

`mise run db:seed` creates or reuses `demo@improve.local` and installs the gym
and vial demo plans if they are not already present.

## Product Workflows

The product kernel is exercised through scenario tests, executable stories,
IEx/code interfaces, Phoenix API endpoints, and the Svelte UI. The main
implemented workflows are:

- install a gym demo plan
- project today's gym work without mutating session history
- start a gym session and preserve recommendation versus swap
- log workout events and complete a session
- install a vial inventory demo plan
- log a dose and derive current vial quantity from item effects
- correct a dose by marking the old event corrected, voiding its effect, and
  creating replacement event/effect records
- return plain-English diagnostics for malformed authored content
- enforce cross-user ownership boundaries
- generate TypeScript contracts for representative resources/actions
- expose read-only AshAI tools for projection, summaries, journal reads, and
  item state
- sign in through the basic auth flow, complete a profile, load the dashboard,
  switch plans, install demo plans, and create new plans from the Svelte UI

Useful IEx examples:

```elixir
alias Improve.{Accounts, Journal, Plans, Sessions}
alias Improve.Fixtures.{GymPlan, VialPlan}

user = Accounts.get_user_by_email!("demo@improve.local")
plans = Plans.list_plans!(actor: user)
gym = Enum.find(plans, &(&1.source_key == "gym"))
vial = Enum.find(plans, &(&1.source_key == "vial_inventory"))

Plans.summarize_plan!(gym, actor: user)

projection = Plans.project_today!(gym, actor: user, date: Date.utc_today())
[projected] = projection.projected_session_occurrences
Sessions.start_projected_session!(projected,
  actor: user,
  started_at: DateTime.utc_now()
)

items = Plans.list_items!(actor: user, query: [filter: [plan_id: vial.id]])
vial_item = Enum.find(items, &(&1.key == "retatrutide_vial_1"))
Journal.get_item_state!(vial_item, actor: user)
```

AshAI tools can be discovered and executed without calling an LLM:

```elixir
tools =
  AshAi.exposed_tools(otp_app: :improve, actor: user)
  |> Map.new(&{to_string(&1.name), &1})

AshAi.Tools.execute(
  tools["get_plan_summary"],
  %{"input" => %{"plan_id" => gym.id}},
  %{actor: user}
)
```

## Verification

For backend-only story/model work, run:

```sh
mise run verify:backend
```

That runs:

- `mix format`
- `mix compile --warnings-as-errors`
- `mix test`
- `mix ash_typescript.codegen --check`
- `pnpm exec tsc --noEmit -p tsconfig.json`
- every executable story under `priv/scripts/stories/*.exs` with `MIX_ENV=test`

Full handoff verification still includes frontend checks and build:

Before handing off changes, run:

```sh
mise run verify
```

That runs:

- `mix format`
- `mix compile --warnings-as-errors`
- `mix test`
- `mix ash_typescript.codegen --check`
- `pnpm exec tsc --noEmit -p tsconfig.json`
- `npm --prefix frontend run check`
- `npm --prefix frontend run build`

The test task starts local Postgres automatically before running ExUnit.

## TypeScript Contracts

AshTypescript generates TypeScript contracts into `priv/generated/`:

- `priv/generated/ash_types.ts`
- `priv/generated/ash_rpc.ts`

Regenerate them after changing exposed Ash resources, actions, or TypeScript RPC
configuration:

```sh
mise run typescript:generate
```

Smoke-check the generated imports with:

```sh
mise run typescript:check
```

## AshAI Tools

The read-only AshAI tools live in `Improve.Ai` and delegate to normal domain
helpers with the supplied actor:

- `project_today`: calls `Plans.project_today/2`
- `get_plan_summary`: calls `Plans.summarize_plan/2`
- `get_recent_journal_events`: calls `Journal.read_journal/2`
- `get_item_state`: calls `Journal.get_item_state/2`

These tools do not write important product data. The smoke tests execute them
through `AshAi.Tools.execute/3` and verify cross-user reads are rejected.

## Still Unresolved

- Authentication and user session wiring are basic and product-shaped, but not
  final.
- The Svelte UI is useful but still early; many screens are placeholders or
  thin flows over the current dashboard API.
- The Phoenix UI API and TypeScript RPC surfaces are intentionally small and
  representative; the final client API still needs deliberate design.
- AshAI is proven as read-only tool exposure, not as a full assistant workflow.
- Authored-plan diagnostics are useful but not a comprehensive schema validator.
- The planner supports only the simple schedule/recommendation rules needed for
  the current product loop.
- Audit/change-history infrastructure beyond the product journal remains
  undecided.

## Direction

The product direction is to keep growing this codebase into Improve. The
architecture should continue to follow the same boundary:

- Ash owns durable domain structure, actions, validation, authorization,
  persistence, and transaction boundaries.
- Plain Elixir modules own deterministic planning, projection, recommendation,
  item state, diagnostics, and review logic.
- Phoenix controllers, the Svelte UI, story scripts, generated TypeScript
  contracts, and AshAI tools expose those same domain operations instead of
  becoming alternate business-rule engines.

The next product work should keep tightening the story/API language, filling
out the Svelte flows, and proving more of the core Improve loop through the
same backend model.
