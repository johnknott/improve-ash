---
# improve-ash-iqm3
title: Log workout events and complete gym session
status: completed
type: task
priority: high
tags:
    - gym
    - journal
created_at: 2026-06-22T19:52:20Z
updated_at: 2026-06-22T20:45:35Z
parent: improve-ash-o8x1
---

## Plan

- [x] Re-read workout logging and completion acceptance criteria.
- [x] Add explicit transactional journal workflow for logging a session item event.
- [x] Link EventInstance, EventItemLink, and SlotResult consistently.
- [x] Add journal read helpers for plan journal and item history ordered by effective time.
- [x] Add scenario test from gym fixture through started session, workout logs, and completion.
- [x] Run verification and close the bean.

## Completed

- Added Journal.log_session_item_event!/2 as an explicit transactional workflow.
- The workflow creates EventInstance and EventItemLink records, then updates the matching SlotResult with event_instance_id.
- SlotResult status remains :swapped for swapped actuals and becomes :completed for matched actuals.
- Added Journal.read_journal/2 and item_history/2 helpers with effective-time ordering.
- Added an end-to-end gym logging scenario for Chest Press, Lat Pulldown, and Bike, followed by completing the session.
- Verified journal order, item history, event links, slot result event links, and completed SessionOccurrence status.
- Verified with mise run verify and mix ash_postgres.generate_migrations --check.
