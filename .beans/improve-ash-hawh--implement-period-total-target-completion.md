---
# improve-ash-hawh
title: Implement period-total target completion
status: completed
type: task
priority: high
created_at: 2026-06-25T09:54:47Z
updated_at: 2026-06-25T10:26:40Z
parent: improve-ash-aszg
blocked_by:
    - improve-ash-xkgr
---

Period-total targets complete when summed logged quantity across the relevant week/month reaches the target amount. The evaluator should compute the period containing the projection date, return progress such as 18 of 25 pages this week, and avoid hidden database or clock access.

## Summary of Changes

- Added a period-total target evaluator.
- Period totals now sum active linked journal quantities across the week or month containing the projection date.
- Progress includes total quantity, target quantity, unit, period bounds, completed event ids, and a readable label.
- Removed period_total from the unsupported target list and moved the remaining unsupported-target test to progression.
- Added period-total unit and projection integration coverage.

Verification:

- mix test test/improve/planning/targets test/improve/planning/project_today_test.exs test/improve/app_test.exs test/improve/stories/stories_test.exs
- mise run verify:backend
