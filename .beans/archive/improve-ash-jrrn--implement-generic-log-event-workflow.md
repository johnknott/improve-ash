---
# improve-ash-jrrn
title: Implement generic log event workflow
status: completed
type: feature
priority: high
created_at: 2026-06-22T21:37:54Z
updated_at: 2026-06-22T22:04:49Z
parent: improve-ash-u392
blocked_by:
    - improve-ash-t1zz
    - improve-ash-ib4w
---

Add a generic journal workflow that creates an event instance, event item links, generated item effects, and optional planned-work links in one transaction. Acceptance: existing workout and dose scenarios can be expressed through the generic path or are ready to migrate.

## Work Checklist

- [x] Inspect current dose/session journal workflows and command shape.
- [x] Add tests for generic event persistence, item links, effect creation, and slot updates.
- [x] Implement generic log event workflow using LogEventCommand and EffectRuleInterpreter.
- [x] Keep existing specific workflows green.
- [x] Run focused tests.
- [x] Run full verification and migration drift check.

## Summary of Changes

Added `Improve.Journal.log_generic_event/2` and `log_generic_event!/2`. The workflow normalizes input with `LogEventCommand`, creates the event, creates all item links, interprets authored effect rules through `EffectRuleInterpreter`, persists generated item effects, and updates a linked slot result when the command includes one.

Added generic workflow tests proving both main current scenarios can be expressed through the generic path: a session item log updates a slot result, and a vial dose log creates an item link and generated quantity effect. Existing specific dose/session workflows remain green and can now be migrated in follow-up beans.

Verification passed with `mise run verify` and `mix ash_postgres.generate_migrations --check`.
