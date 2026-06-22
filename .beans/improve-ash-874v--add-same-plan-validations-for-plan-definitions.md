---
# improve-ash-874v
title: Add same-plan validations for plan definitions
status: completed
type: feature
priority: high
created_at: 2026-06-22T21:38:29Z
updated_at: 2026-06-22T21:51:16Z
parent: improve-ash-dcal
blocked_by:
    - improve-ash-byh8
---

Ensure item types, items, pools, memberships, environments, event types, session templates, slots, direct goals, and schedules cannot reference records from another plan. Acceptance: negative tests cover mixed-plan definition writes.

## Work Checklist

- [x] Check installed Ash/AshPostgres versions and current docs for validations/changes.
- [x] Add same-owner mixed-plan negative tests for authored plan definitions.
- [x] Implement same-plan checks for plan definition resources.
- [x] Run focused tests.
- [x] Run project verification if the focused pass is clean.

## Summary of Changes

Added resource-level same-plan validation for authored plan definitions. The new reusable `Improve.Validations.SamePlan` validation checks ordinary foreign keys, array-backed item references, and polymorphic schedule owners against the submitted row plan.

Covered same-owner/two-plan negative cases for items, pool memberships, environments, session templates, session slots, direct goals, and schedules. Updated the authored-content test so schedules point at real plan-owned owners instead of arbitrary UUIDs.

Verification passed with `mise run verify` and `mix ash_postgres.generate_migrations --check`.
