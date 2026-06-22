# Improve Ash

Improve Ash is a headless Phoenix/Ash proof-of-concept for the Improve product
model.

The active product spike is described in `notes/spike-spec.md`. The broader
future product direction is in `notes/full-rewrite-spec.md`; it is useful
context, but it is not the current build scope.

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
test watcher, and IEx.

## Database

Common local commands:

```sh
mise run db:create
mise run db:migrate
mise run db:seed
```

`mise run db:reset` drops and recreates local data, so use it deliberately.

## Verification

Before handing off changes, run:

```sh
mise run verify
```

That runs:

- `mix format`
- `mix compile --warnings-as-errors`
- `mix test`

The test task starts local Postgres automatically before running ExUnit.
