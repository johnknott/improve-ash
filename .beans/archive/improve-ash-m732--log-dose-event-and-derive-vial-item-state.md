---
# improve-ash-m732
title: Log dose event and derive vial item state
status: completed
type: task
priority: high
tags:
    - vial
    - effects
created_at: 2026-06-22T19:52:20Z
updated_at: 2026-06-22T20:51:37Z
parent: improve-ash-o8x1
---

## Plan

- [x] Re-read dose logging acceptance criteria.
- [x] Add explicit transactional dose logging workflow that creates EventInstance, EventItemLink, and ItemEffect.
- [x] Interpret Take Dose effect rules from the event type rather than hard-coding effect creation in the test.
- [x] Add Journal.get_item_state/2 using persisted active effects plus pure Planning.ItemState.
- [x] Add scenario test using the vial fixture.
- [x] Run verification and close the bean.

## Completed

- Added Journal.log_dose_event!/2 as an explicit transactional workflow.
- The workflow creates EventInstance, source_vial EventItemLink, and ItemEffect records from the Take Dose effect rule.
- Added Journal.get_item_state/2 and get_item_state!/2 to derive state from persisted item effects through Improve.Planning.ItemState.
- Added scenario test proving a 250 mcg dose subtracts from Retatrutide vial 1 and derives 4750 mcg remaining.
- Verified event/effect active status, source vial link, effect quantity/unit, and derived state.
- Verified with mise run verify and mix ash_postgres.generate_migrations --check.
