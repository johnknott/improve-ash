---
# improve-ash-e7vd
title: Implement metric and checklist target completion
status: completed
type: task
priority: high
created_at: 2026-06-25T09:54:47Z
updated_at: 2026-06-25T10:23:55Z
parent: improve-ash-aszg
blocked_by:
    - improve-ash-xkgr
---

Metric targets complete when the user records a value for the date, with progress showing the recorded value. Checklist targets complete when logged checklist items for the date cover the target checklist, with progress such as 3 of 5. Include unit tests and projection integration coverage.

## Summary of Changes

- Added metric and checklist target evaluators behind the internal target completion contract.
- Taught target dispatch to recognize explicit type values, UI mode values, metric naming, checklist_items, and legacy progression shapes.
- Metric targets now complete only when a same-day linked event records a value, with recorded value progress.
- Checklist targets now complete when same-day linked events cover the required item set, with count and item progress.
- Updated stale unsupported-target expectations now that metric and checklist are implemented.

Verification:

- mix test test/improve/stories/stories_test.exs test/improve/planning/targets test/improve/planning/project_today_test.exs test/improve/app_test.exs test/improve_web/app_controller_test.exs
- mise run verify:backend
