---
# improve-ash-t1zz
title: Define generic event logging command shape
status: completed
type: task
priority: high
created_at: 2026-06-22T21:37:54Z
updated_at: 2026-06-22T22:02:03Z
parent: improve-ash-u392
---

Design the server command input for generic event logging: event type, effective/recorded timestamps, payload, item links with roles, optional session occurrence, slot result, direct goal, origin, and idempotency fields. Acceptance: shape is documented and reflected in tests or structs.

## Work Checklist

- [x] Inspect current journal command inputs and full rewrite event/offline notes.
- [x] Define a generic event logging command shape in code.
- [x] Cover command normalization/validation with focused tests.
- [x] Document how it maps to future generic logging and offline/idempotent ingress.
- [x] Run focused tests.
- [x] Run full verification and migration drift check.

## Summary of Changes

Added `Improve.Journal.LogEventCommand`, a plain Elixir command shape for generic event logging. It normalizes event type, effective/recorded timestamps, payload, optional planned-work links, item links with roles, origin, replacement event ID, and nested idempotency metadata for future offline retries.

Added focused tests for command normalization, default manual logging, plain-English diagnostics, safe string-origin handling, and extracting event attrs without command-only item/idempotency data.

This does not persist events yet. It establishes the command boundary for the follow-up generic log-event workflow bean. Verification passed with `mise run verify` and `mix ash_postgres.generate_migrations --check`.
