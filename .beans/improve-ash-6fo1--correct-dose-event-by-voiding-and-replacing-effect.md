---
# improve-ash-6fo1
title: Correct dose event by voiding and replacing effects
status: completed
type: task
priority: high
tags:
    - vial
    - correction
created_at: 2026-06-22T19:52:20Z
updated_at: 2026-06-22T20:56:12Z
parent: improve-ash-o8x1
---

- [x] Re-read correction acceptance criteria.
- [x] Add explicit transactional dose correction workflow.
- [x] Mark original event corrected and original effect voided without deletion.
- [x] Create replacement EventInstance and ItemEffect with replacement relationships.
- [x] Prove derived item state ignores old voided effect and uses replacement effect.
- [x] Run verification and close the bean.

## Result

Implemented `Journal.correct_dose_event!/2` as an explicit transaction. It marks the original dose event corrected, voids the original item effect, creates a replacement event/source-vial link/item effect, and stores replacement relationships without deleting history.

Added `test/improve/journal/dose_correction_test.exs` to prove a 250 mcg dose corrected to 300 mcg produces a final vial state of 4700 mcg, retains journal history, and ignores the voided original effect.

Verification:

- `mise run verify`
- `mix ash_postgres.generate_migrations --check`
