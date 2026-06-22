---
# improve-ash-jcmd
title: Install gym demo plan and prove persisted references
status: completed
type: task
priority: high
tags:
    - gym
    - fixture
created_at: 2026-06-22T19:52:11Z
updated_at: 2026-06-22T20:36:42Z
parent: improve-ash-o8x1
---

## Plan

- [x] Re-read gym installation requirements from the spike spec.
- [x] Add a plain Elixir gym fixture installer that runs in an explicit transaction.
- [x] Persist the gym plan, item types, items, pools, memberships, environment, event types, session template, slots, and schedule.
- [x] Add a small plan summary helper for fixture verification.
- [x] Add scenario-style tests proving persisted references and useful counts.
- [x] Run verification and close the bean.

## Completed

- Added Improve.Fixtures.GymPlan.install!/2 with explicit starts_on input and transactional installation.
- Installed the General Fitness demo plan with item types, items, pools, pool memberships, environment, event types, session template, session slots, and times-per-week schedule.
- Added Plans.summarize_plan/2 and summarize_plan!/2 for useful count summaries through policy-scoped code interfaces.
- Allowed Plan create/update actions to accept status so demo installers can create active plans directly.
- Added scenario-style test proving persisted gym fixture content, valid references, no orphaned memberships/slots, and expected summary counts.
- Handled Ash transactional notifications correctly instead of silencing warnings.
- Verified with mise run verify and mix ash_postgres.generate_migrations --check.
