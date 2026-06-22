---
# improve-ash-yyzl
title: Add item pool environment event type and schedule resources
status: completed
type: task
priority: high
tags:
    - ash
    - model
created_at: 2026-06-22T19:52:03Z
updated_at: 2026-06-22T20:22:30Z
parent: improve-ash-n3bi
---

## Plan

- [x] Check installed Ash/AshPostgres docs for relationship policy patterns and migrations.
- [x] Add authored plan content resources: ItemType, Item, Pool, PoolMembership, Environment, EventType, Schedule.
- [x] Expose focused code interfaces from Improve.Plans.
- [x] Generate/apply AshPostgres migrations and snapshots.
- [x] Add tests for creating authored content and cross-user isolation through plan ownership.
- [x] Run verification and migration drift checks.

## Completed

- Added authored plan content resources under Improve.Plans with AshPostgres persistence.
- Added plan ownership policies to authored resources via their parent plan.
- Added code interfaces for create/get/list actions on the new resources.
- Added Plan relationships for item types, items, pools, memberships, environments, event types, and schedules.
- Generated and applied the authored content migration plus Ash resource snapshots.
- Added tests for authored content creation/listing and cross-user isolation.
- Verified with mise run verify and mix ash_postgres.generate_migrations --check.
