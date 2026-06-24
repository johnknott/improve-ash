# Agent Instructions

Read this file in full before doing project work.

This repository is **Improve Ash**, an early full-stack V2 prototype for
Improve. It is not the existing Go/React app, and it is not yet a production
rewrite, but the Ash product kernel, Phoenix API, story scripts, generated
contracts, and Svelte UI are all part of the prototype.

## Required Project Context

The files in `notes/` are real project inputs, not scratch notes.

Read these before making architectural or implementation decisions:

- `notes/story-api-improvement-plan.md`: the current product-language and
  product-facing API direction for stories, UI-facing helpers, target
  vocabulary, schedules, sessions, stateful items, and review flows.

If `README.md` exists, read it after the notes. If future architecture notes are
added, read those too.

## Current Project Shape

The goal is an early full-stack prototype using Elixir, Phoenix, Ash,
AshPostgres, Postgres, plain Elixir modules, and a Svelte/TypeScript frontend.

The prototype should prove the core Improve model and workflows through tests,
seeds, IEx/code interfaces, story scripts, generated TypeScript contracts,
Phoenix app APIs, a Svelte UI, and small read-only AshAI experiments. Keep the
scope focused on the V2 product loop. Do not build a React UI, LiveView UI,
admin area, billing, Stripe integration, mobile client, or full offline sync
system unless the user explicitly expands the scope.

When building Svelte UI, prefer Bits UI primitives/components where they fit the
interaction. Style them locally so the interface still feels like Improve
rather than a generic component demo.

The main product model is:

- users own plans
- plans contain product-facing tracks, item types, items, pools, environments,
  event types, sessions, schedules, and journal history
- session templates project into session occurrences
- slot results preserve recommendations, swaps, completion, and links to events
- event instances are the user-facing journal of what actually happened
- event item links attach involved items with roles
- item effects record state changes
- current item state is derived from starting facts plus active item effects
- deterministic planning/recommendation logic lives in plain Elixir modules,
  outside Ash resource DSL blocks

## Architectural Boundaries

Keep building the Ash way: **Model your domain, derive the rest.**

When a rule is part of the durable product model, prefer expressing it where Ash
can see and reuse it:

- resources and relationships for domain structure
- named actions for business operations
- attributes, identities, validations, changes, preparations, policies,
  calculations, aggregates, and atomics for enforceable rules
- code interfaces, generated contracts, and AshAI tools as thin exposures of
  those actions

Use service/facade modules for orchestration, input translation, demo fixture
installation, and explicit multi-step transactions, but do not hide core rules
there if they can live clearly on an Ash resource/action. Phoenix controllers,
frontend code, story scripts, and assistant tools should not become alternate
business-rule engines.

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
right tool versions installed, so expect to add or maintain `.mise.toml` as part
of bootstrapping.

Install tools with:

```sh
mise install
```

The intended local development shape should mirror the useful parts of
`../improve-app`:

- `.mise.toml` declares language/runtime/tool versions and common tasks
- `docker-compose.yml` runs local Postgres
- a small script ensures Postgres is running before dev tasks start
- `mise run dev` opens or attaches to a zellij session
- the zellij layout runs the Phoenix server and any useful watchers in panes

Do not copy Go/sqlc/Vite/Stripe tasks from `../improve-app` unless they are
actually relevant to this V2 prototype. Borrow the orchestration pattern, not
the old app's architecture.

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

Before adding a new Mix package, check Elixir Observer categories first:
`https://elixir-observer.com/categories`. Use it to understand the current
package landscape and nearby alternatives. Still verify the chosen package
against Hex.pm, HexDocs, the package repository, compatibility constraints, and
this prototype's scope before adding it.

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

Build toward the product stories and API shape in
`notes/story-api-improvement-plan.md` and the existing scenario tests.

Near-term implementation should keep moving the prototype toward these
product-facing stories:

- create a plan in friendly product language
- add tracks with clear target and schedule vocabulary
- group work into sessions with slots, pools, recommendations, swaps, and
  actual results
- project today's tracks and sessions without mutating journal history
- log what actually happened through generic events and track/session helpers
- correct mistakes by preserving auditable journal history
- derive item state from starting facts plus active effects
- return plain-English diagnostics for invalid authored content
- expose useful Phoenix/Svelte flows without duplicating business rules in the
  UI
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
  supplement inventory. The prototype can model tracking behavior, but it
  should not give medical advice.
