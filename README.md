# Improve Ash

Improve Ash is a Phoenix/Ash proof-of-concept for the Improve product model.

The current product-language and story/API direction is described in
`notes/story-api-improvement-plan.md`.

This repo is intentionally not building a React UI, LiveView UI, admin section,
billing, full auth, mobile client, or full offline sync system yet. The spike is
about proving the product kernel with Ash resources, Postgres persistence,
plain Elixir planning modules, scenario tests, generated TypeScript contracts,
and small read-only AshAI tool experiments.

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

The first frontend app lives in `frontend/`. It is a plain Svelte + TypeScript
+ Vite app with no routing, auth, styling framework, component library, or API
wiring yet.

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

## Spike Workflows

The POC is exercised primarily through scenario tests and IEx/code interfaces.
The main implemented stories are:

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

AshTypescript generates the spike contracts into `priv/generated/`:

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

- There is no real authentication or user session wiring.
- There is no UI; tests and IEx are the interface for this spike.
- The TypeScript RPC surface is intentionally small and representative, not the
  final client API.
- AshAI is proven as read-only tool exposure, not as a full assistant workflow.
- Authored-plan diagnostics are useful but not a comprehensive schema validator.
- The planner supports only the simple schedule/recommendation rules needed for
  the spike.
- Audit/change-history infrastructure beyond the product journal remains
  undecided.

## POC Verdict Checklist

1. Are the resources/actions easier to understand than the Go/sqlc version?
   Tentatively yes: the resource graph now reads close to the product model.
2. Are the hard workflows smaller?
   Yes for the tested workflows; explicit orchestration modules kept the complex
   journal/session flows approachable.
3. Are transaction boundaries clear?
   Yes: session start, event logging, dose logging, and correction are explicit
   transactions.
4. Are errors and diagnostics understandable?
   Improving: authored-content diagnostics are plain English, while raw Ash
   errors still need UI-facing translation later.
5. Does generated TypeScript look good enough for a future React/shadcn app?
   Yes for representative read contracts; the final app API still needs design.
6. Do AshAI tools feel naturally derived from domain actions?
   Yes: the useful tool layer is thin once the normal domain helpers exist.
7. Is debugging acceptable?
   Yes so far: pure modules and scenario tests make failures local and readable.
8. Would we be comfortable building the real product on this?
   Tentatively yes, with real auth, a deliberate client API, and continued care
   around keeping deterministic planning outside framework DSL hooks.
