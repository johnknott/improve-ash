---
# improve-ash-ib4w
title: Extract pure effect rule interpreter
status: completed
type: feature
priority: high
created_at: 2026-06-22T21:37:54Z
updated_at: 2026-06-22T21:58:47Z
parent: improve-ash-u392
---

Move effect rule interpretation into a pure module that receives event type rules, item links, payload, and timestamps, then returns effect specs and diagnostics. Acceptance: interpreter has unit tests and does not read the database or mutate history.

## Work Checklist

- [x] Inspect current vial effect rule shape and dose logging behavior.
- [x] Add focused unit tests for a pure effect rule interpreter.
- [x] Implement the pure interpreter without database, clock, or mutation dependencies.
- [x] Route existing dose effect creation through the interpreter.
- [x] Run focused journal/effect tests.
- [x] Run full verification and migration drift check.

## Summary of Changes

Added `Improve.Planning.EffectRuleInterpreter`, a pure module that receives authored effect rules, event item links, and payload data, then returns effect specs plus plain-English diagnostics. It has focused unit coverage for happy-path quantity effects, multiple links for a role, missing links, unsupported effect types, and missing payload paths.

Updated dose logging and dose correction to route effect creation through the interpreter while preserving current persisted journal behavior. The persistence step remains in `Improve.Journal`; the rule interpretation now lives in deterministic plain Elixir.

Verification passed with `mise run verify` and `mix ash_postgres.generate_migrations --check`.
