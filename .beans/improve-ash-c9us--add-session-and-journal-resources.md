---
# improve-ash-c9us
title: Add session and journal resources
status: completed
type: task
priority: high
tags:
    - ash
    - journal
created_at: 2026-06-22T19:52:03Z
updated_at: 2026-06-22T20:27:28Z
parent: improve-ash-n3bi
---

## Plan

- [x] Check installed Ash/AshPostgres docs for optional relationships, numeric/atom attributes, and migrations.
- [x] Add authored session resources: SessionTemplate, SessionSlot, DirectGoal.
- [x] Add runtime session resources under Improve.Sessions: SessionOccurrence, SlotResult.
- [x] Add journal resources under Improve.Journal: EventInstance, EventItemLink, ItemEffect.
- [x] Register new domains and expose focused code interfaces.
- [x] Generate/apply migrations and snapshots.
- [x] Add tests for session/journal creation and ownership isolation.
- [x] Run verification and migration drift checks.

## Completed

- Added session template, session slot, and direct goal authored resources under Improve.Plans.
- Added Improve.Sessions with session occurrences and slot results.
- Added Improve.Journal with event instances, event item links, and item effects.
- Added ownership policies through plan.user_id across runtime and journal resources.
- Registered Improve.Sessions and Improve.Journal in ash_domains and exposed code interfaces.
- Generated and applied the sessions/journal migration plus snapshots.
- Added tests covering recommendation preservation, event linking, item effects, and cross-user isolation.
- Verified with mise run verify and mix ash_postgres.generate_migrations --check.
