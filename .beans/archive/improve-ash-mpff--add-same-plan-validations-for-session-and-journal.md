---
# improve-ash-mpff
title: Add same-plan validations for session and journal writes
status: completed
type: feature
priority: high
created_at: 2026-06-22T21:38:29Z
updated_at: 2026-06-22T21:55:26Z
parent: improve-ash-dcal
blocked_by:
    - improve-ash-byh8
---

Ensure session occurrences, slot results, events, event item links, and item effects cannot mix IDs across plans. Acceptance: negative tests prove cross-plan session/journal writes fail even when the actor owns both plans.

## Work Checklist

- [x] Re-check the relevant Ash validation/action docs and installed versions.
- [x] Add same-owner mixed-plan negative tests for session writes.
- [x] Add same-owner mixed-plan negative tests for journal writes.
- [x] Wire same-plan validations into session and journal resources.
- [x] Run focused tests.
- [x] Run full verification and migration drift check.

## Summary of Changes

Added same-plan validation to runtime and journal write resources: session occurrences, slot results, event instances, event item links, and item effects. Slot result completion/swap now validates accepted actual item and event IDs against the slot result plan.

Added same-owner/two-plan negative tests covering session occurrence creation, slot result creation/update, event logging, event item links, and item effects. These prove a user cannot cross-wire IDs between two plans they own.

Verification passed with `mise run verify` and `mix ash_postgres.generate_migrations --check`.
