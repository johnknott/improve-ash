---
# improve-ash-kwgy
title: Install vial demo plan and validate effect rules
status: completed
type: task
priority: high
tags:
    - vial
    - fixture
created_at: 2026-06-22T19:52:11Z
updated_at: 2026-06-22T20:49:29Z
parent: improve-ash-o8x1
---

## Plan

- [x] Re-read vial fixture requirements from the spike spec.
- [x] Add a plain Elixir vial fixture installer with explicit starts_on and transaction handling.
- [x] Persist the vial plan, item types, items, event type, item link roles, and subtract quantity effect rule.
- [x] Add lightweight authored-content diagnostics for event type role/effect-rule consistency.
- [x] Add scenario tests proving persisted vial content and valid effect rules.
- [x] Run verification and close the bean.

## Completed

- Added Improve.Fixtures.VialPlan.install!/2 with explicit starts_on input and transactional installation.
- Installed the Retatrutide Inventory demo plan with Peptide Vial and Injection Site item types.
- Installed Retatrutide vial 1 with starting quantity facts and Abdomen as an injection site item.
- Installed Take Dose event type with source_vial/site item link roles and a subtract_quantity effect rule for payload amount/unit.
- Added Improve.Planning.Diagnostics.validate_event_type/1 for effect-rule role consistency.
- Added tests proving persisted vial content, starting facts, valid effect rules, and plain-English diagnostics for undeclared roles.
- Verified with mise run verify and mix ash_postgres.generate_migrations --check.
