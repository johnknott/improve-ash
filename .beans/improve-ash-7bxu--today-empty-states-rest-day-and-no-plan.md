---
# improve-ash-7bxu
title: 'Today empty states: rest day and no plan'
status: completed
type: task
priority: normal
created_at: 2026-07-04T22:29:17Z
updated_at: 2026-07-04T22:48:41Z
parent: improve-ash-0m50
blocked_by:
    - improve-ash-hmnn
---

No plan → keep the existing DemoPlanSetup path (install demo / create plan). Plan with no work today → an intentional 'rest day' state, not a bare empty list: EmptyState (icon snippet from Phase 0) with calm copy, plus the upcoming strip so the day still has shape. Distinguish genuinely-empty from on-hold-everything if the payload makes that visible.

## Summary of Changes

No-plan keeps the DemoPlanSetup path. No-work renders a "Rest day" EmptyState with Leaf icon; copy mentions "the plan picks back up below" only when the upcoming strip is non-empty (the vial plan has no scheduled tracks at all, so it gets the plain variant). Verified visually on both demo plans.
