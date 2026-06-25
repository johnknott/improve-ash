---
# improve-ash-x3yd
title: Implement progression target completion
status: completed
type: task
priority: high
created_at: 2026-06-25T09:54:57Z
updated_at: 2026-06-25T10:30:00Z
parent: improve-ash-aszg
blocked_by:
    - improve-ash-xkgr
---

Progression targets should calculate the expected amount for the projection date from the configured from/to/date range and then complete like a fixed target against that expected amount. Include boundary tests for start, middle, and end dates plus projection integration coverage.

## Summary of Changes

- Added plan context to target evaluator input so progression can derive expected amounts from the plan date range.
- Added a progression target evaluator.
- Progression targets now interpolate the expected amount for the projection date from from/to over target or plan dates.
- Same-day linked logged quantities complete progression targets once they meet the expected amount.
- Supported both explicit progression targets and legacy targets with a nested progression map.
- Moved the remaining unsupported-target diagnostic expectation to adaptive.

Verification:

- mix test test/improve/planning/targets test/improve/planning/project_today_test.exs test/improve/app_test.exs test/improve/stories/stories_test.exs
- mise run verify:backend
