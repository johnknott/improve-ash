---
# improve-ash-9v9s
title: Return plain English diagnostics for invalid authored content
status: completed
type: task
priority: high
tags:
    - diagnostics
created_at: 2026-06-22T19:52:20Z
updated_at: 2026-06-22T21:01:49Z
parent: improve-ash-o8x1
---

- [x] Re-read the required diagnostics in the spike spec.
- [x] Inspect the current diagnostics module and fixture shapes.
- [x] Add small plain-English authored-plan diagnostics for required invalid content cases.
- [x] Add focused scenario tests that prove validation does not crash and includes useful path/ref details.
- [x] Run verification and close the bean.

## Result

Added `Diagnostics.validate_plan_draft/1` for authored plan maps with plain-English diagnostics shaped for display: severity, code, message, path, ref, and details.

Covered the spike-required invalid content cases: duplicate keys, missing session-slot pool, missing event-role item type, effect rule pointing at an undeclared role, invalid schedule kind, unsupported schedule rule, missing required source vial link, and incompatible dose quantity for an effect rule.

Kept `Diagnostics.validate_event_type/1` compatible with the existing vial fixture check while adding path/ref metadata.

Verification:

- `mix test test/improve/planning/diagnostics_test.exs test/improve/fixtures/vial_plan_test.exs`
- `mise run verify`
- `mix ash_postgres.generate_migrations --check`
