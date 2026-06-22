---
# improve-ash-lxmd
title: Start gym session and preserve recommended versus actual slot items
status: completed
type: task
priority: high
tags:
    - gym
    - session
created_at: 2026-06-22T19:52:11Z
updated_at: 2026-06-22T20:42:49Z
parent: improve-ash-o8x1
---

## Plan

- [x] Re-read start-session scenario requirements from the spike spec.
- [x] Add a workflow function that persists a projected occurrence as a started SessionOccurrence.
- [x] Create SlotResult rows preserving recommended and actual items.
- [x] Keep the workflow explicit and transactional.
- [x] Add scenario tests using the gym fixture and project_today output.
- [x] Run verification and close the bean.

## Completed

- Added Sessions.start_projected_session!/2 as an explicit transactional workflow.
- The workflow creates a started SessionOccurrence from a projected occurrence and stores the recommendation snapshot.
- The workflow creates SlotResult rows for all recommended items and records actual item overrides by slot key.
- SlotResult status is :swapped when actual differs from recommended.
- Plans.project_today/2 can now accept explicit recent_item_ids for deterministic recommendation tests.
- Added a scenario test proving Rower was recommended, Bike was chosen, and the persisted SlotResult preserves both.
- Verified with mise run verify and mix ash_postgres.generate_migrations --check.
