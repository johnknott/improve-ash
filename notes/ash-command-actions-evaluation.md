# Ash Command Actions Evaluation

This note evaluates whether the current command workflows should move toward
Ash generic actions or relationship-managed actions.

Installed versions checked:

- Ash `3.29.1` from `mix.lock`
- AshPostgres `2.10.0` from `mix.lock`

Official docs checked:

- `https://ash.hexdocs.pm/generic-actions.html`
- `https://ash.hexdocs.pm/actions.html`
- `https://ash.hexdocs.pm/Ash.Changeset.html`

## Current Recommendation

Keep the current command workflows as plain Elixir orchestration for now.

Do not add a generic-action pilot in this spike. A pilot would mostly wrap the
same functions in Ash DSL without removing meaningful complexity. The current
shape already keeps deterministic command inputs in plain structs, uses Ash
resource actions for the actual persisted records, preserves explicit
transactions, and now raises structured `Improve.CommandError` exceptions from
bang command boundaries.

This is still compatible with moving selected commands into Ash generic actions
later when we need public API exposure, a typed RPC contract, or shared Ash
authorization at the outer command level.

## What The Docs Imply

Ash generic actions take typed arguments and return a declared value. They are
called through `Ash.ActionInput` and `Ash.run_action`, can participate in code
interfaces, support validations and preparations, and can be made transactional
with `transaction? true`.

The docs also explicitly say regular Elixir functions are fine when those
benefits are not needed. That matters here: these commands currently act as
headless product-kernel orchestration, not public JSON/RPC actions.

## Workflow Evaluation

### Start Projected Session

Current shape:

- plain Elixir function on `Improve.Sessions`
- creates one `SessionOccurrence`
- creates many `SlotResult` records
- stores the recommendation snapshot
- collects Ash notifications and emits them after commit

Generic-action fit:

- Possible later, probably on `SessionOccurrence` or a command resource.
- Not clearly better right now because the input is a projected occurrence
  struct, not a simple client payload.
- The current workflow benefits from explicit construction of slot results and
  a plain return map.

Decision: keep as plain Elixir until a real client/API needs a typed command
surface for starting sessions.

### Log Generic Event

Current shape:

- normalizes input through `Improve.Journal.LogEventCommand`
- checks idempotency and stale offline references
- creates `EventInstance`, `EventItemLink`, and `ItemEffect` records
- updates a linked `SlotResult` when applicable
- returns accepted or duplicate command results

Generic-action fit:

- Plausible future candidate because it is a product command.
- Would need a declared return shape for event, links, effects, slot result,
  and idempotency status.
- `manage_relationship` is not a natural fit yet because item links and effects
  are derived from authored event type rules, not simply accepted nested input.

Decision: keep the current command function. Revisit when exposing write RPC
contracts to a UI or mobile client.

### Correct Generic Event

Current shape:

- validates correction command input
- marks the original event corrected
- voids original effects
- creates replacement event, links, and replacement effects
- preserves auditable history

Generic-action fit:

- Possible, but less attractive than logging because it crosses old and new
  records with replacement semantics.
- A generic action wrapper would not remove the need for the explicit ledger
  logic.

Decision: keep as plain Elixir for now.

### Install Demo Plans

Current shape:

- fixture/demo plan orchestration
- creates authored plan content for tests, seeds, and IEx exploration

Generic-action fit:

- Poor. This is not a product write command and should not become public API.

Decision: keep as fixtures/plain Elixir.

## Future Trigger For Reconsideration

Reconsider generic actions when one of these becomes true:

- the React/mobile client needs typed write contracts for these workflows
- AshTypescript should generate command inputs for event logging or session
  starting
- AshAI should call a write command after explicit user approval
- we need outer-command Ash policies beyond the existing per-record policies
- a command return type becomes stable enough to model as an embedded resource
  or clearly typed struct

The likely first candidate is `log_generic_event` or offline batch ingress, not
demo plan installation.
