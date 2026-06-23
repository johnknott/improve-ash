# Agent Instructions

Read this file in full before doing project work.

This repository is **Improve Ash**, a headless product spike for Improve. It is
not the existing Go/React app, and it is not yet the full product rebuild.

## Required Project Context

The files in `notes/` are real project inputs, not scratch notes.

Read these before making architectural or implementation decisions:

- `notes/spike-spec.md`: the product spike we are building now. Treat this as
  the primary specification for scope, acceptance criteria, and deliverables.
- `notes/full-rewrite-spec.md`: the broader plain-English product direction.
  Use this as reference context only. Do not build the full product unless the
  user explicitly expands the scope.

If `README.md` exists, read it after the notes. If future architecture notes are
added, read those too.

## Current Project Shape

The goal is a small headless proof-of-concept using Elixir, Phoenix, Ash,
AshPostgres, Postgres, and plain Elixir modules.

The POC should prove the core Improve model and workflows through tests, seeds,
IEx/code interfaces, generated TypeScript contracts, and a small read-only
AshAI experiment. Do not build a React UI, LiveView UI, admin area, billing,
Stripe integration, full passwordless auth, mobile client, or full offline sync
system for this spike.

When building Svelte UI for this spike, prefer Bits UI primitives/components
where they fit the interaction. Style them locally so the interface still feels
like Improve rather than a generic component demo.

The main product model is:

- users own plans
- plans contain item types, items, pools, environments, event types, sessions,
  direct goals, schedules, and journal history
- session templates project into session occurrences
- slot results preserve recommendations, swaps, completion, and links to events
- event instances are the user-facing journal of what actually happened
- event item links attach involved items with roles
- item effects record state changes
- current item state is derived from starting facts plus active item effects
- deterministic planning/recommendation logic lives in plain Elixir modules,
  outside Ash resource DSL blocks

## Architectural Boundaries

Use Ash where it makes the product model clearer:

- resources and relationships
- actions and code interfaces
- policies and ownership checks
- validations
- persistence through AshPostgres
- TypeScript contract generation
- read-only AshAI tool exposure

Use plain Elixir where it is clearer and easier to test:

- deterministic projection
- session recommendation rules
- item state calculation
- authored-plan diagnostics
- fixture/demo plan installation orchestration
- multi-step transactions such as logging and correcting events

Planning modules must not read the database, call AI, call HTTP, send email,
read wall-clock time directly, use hidden randomness, or mutate journal history.
Pass explicit inputs in and return explicit outputs.

Do not replace the product journal with AshEvents. If AshEvents is tried, it is
only for optional infrastructure audit/change history.

## Development Tooling

Use `mise` for local tools and project tasks. This repo may start without the
right tool versions installed, so expect to add or maintain `mise.toml` as part
of bootstrapping.

Install tools with:

```sh
mise install
```

The intended local development shape should mirror the useful parts of
`../improve-app`:

- `mise.toml` declares language/runtime/tool versions and common tasks
- `docker-compose.yml` runs local Postgres
- a small script ensures Postgres is running before dev tasks start
- `mise run dev` opens or attaches to a zellij session
- the zellij layout runs the Phoenix server and any useful watchers in panes

Do not copy Go/sqlc/Vite/Stripe tasks from `../improve-app` unless they are
actually relevant to this Ash spike. Borrow the orchestration pattern, not the
old app's architecture.

Expected task names may evolve, but prefer this shape:

- `mise run dev`: start local Postgres and attach to the zellij dev session
- `mise run test`: run ExUnit tests
- `mise run fmt`: run Elixir formatting
- `mise run lint`: run static checks if configured
- `mise run verify`: run formatting/checks/tests suitable before handoff
- `mise run db:create`: create the local database if needed
- `mise run db:migrate`: run migrations
- `mise run db:reset`: reset local development data when explicitly wanted
- `mise run db:seed`: seed demo gym and vial plans
- `mise run typescript:generate`: regenerate AshTypescript output

When exact tool versions are not established yet, choose current stable versions
unless a documented compatibility constraint says otherwise.

## Ash Documentation Discipline

Ash and its extensions move quickly. Do not rely on memory for non-trivial Ash,
AshPostgres, AshTypescript, AshAI, AshOban, or AshEvents APIs.

Before adding or changing meaningful Ash DSL, actions, policies, migrations,
code interfaces, TypeScript generation, or AI tool exposure:

- Check the installed package versions in `mix.lock` or with Mix.
- Read the current official docs for those versions, preferably HexDocs:
  `https://ash.hexdocs.pm/`, `https://ash-postgres.hexdocs.pm/`,
  `https://ash-typescript.hexdocs.pm/`, and `https://ash-ai.hexdocs.pm/`.
- Prefer official guides, API docs, generated docs, and package changelogs over
  examples from memory, old blog posts, or unrelated projects.
- If the docs and an example disagree, trust the docs for the installed version
  and mention the decision in the implementation notes when it matters.

## Beans

Beans is not assumed to be installed yet in this repository.

If `beans` is available, run `beans prime` and heed its output. If it is not
available, note that briefly and continue with the project workflow. Do not let
missing Beans block small direct work.

Use Beans only for substantial work that benefits from planning or
decomposition. Do not create Beans for tiny edits, quick checks, or short
discussion-only turns unless the user explicitly asks.

Before starting implementation on a Bean, explain the intended approach in
friendly plain English and wait for the user's agreement.

## Implementation Priorities

Build toward the scenario tests in `notes/spike-spec.md`.

The first meaningful implementation should stay close to these product stories:

- install a gym demo plan
- project today's gym work without mutating the database
- start a gym session and preserve a recommendation/swap
- log workout events and complete the session
- install a vial inventory demo plan
- log a dose and create an item effect
- correct a dose by voiding/replacing the event and effect
- return plain-English diagnostics for invalid authored content
- generate TypeScript contracts with AshTypescript
- expose small read-only AshAI tools using normal domain actions

Keep transactions explicit for workflows that create or correct journal data.
Clarity is more important than forcing everything into Ash DSL hooks.

## Coding Style

Prefer boring clarity over clever framework gymnastics.

- Make small, safe, incremental changes.
- Keep diffs focused.
- Avoid premature abstractions.
- Add dependencies only when they clearly reduce complexity.
- Keep generated code out of manual edits.
- Keep functions small and single-purpose where practical.
- Use plain-English diagnostics where errors can reach users or plan authors.
- Apply the Boy Scout rule when touching a file: remove dead code, unused
  imports, and stale comments nearby.

If a proposed solution needs a large amount of new internal code, pause and
explain the approach before implementing so the user can steer scope.

## Communication Style

When discussing product direction, architecture, tradeoffs, or next steps, use
friendly plain English. Avoid long bullet-heavy replies unless structure really
helps. Technical detail is welcome, but keep it easy to talk through.

## Safety

- Never print or commit secrets.
- Ask before destructive actions such as deleting data, resetting databases,
  force-pushing, or removing files the user did not explicitly ask to remove.
- Be careful with health-adjacent examples such as medication, peptide, and
  supplement inventory. The spike can model tracking behavior, but it should
  not give medical advice.
