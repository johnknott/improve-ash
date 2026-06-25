---
# improve-ash-xkgr
title: Widen target evaluators to decide completion and progress
status: completed
type: feature
priority: high
created_at: 2026-06-25T09:54:47Z
updated_at: 2026-06-25T10:16:06Z
parent: improve-ash-aszg
---

Extend the internal target evaluator shape so it receives the date and bounded journal events, returns completion status/progress plus diagnostics, and moves the existing fixed-target any-event-on-date completion rule behind Improve.Planning.Targets.Fixed. Done when fixed targets still project exactly as before but through the target evaluator path.

## Summary of Changes

- Extended the internal target evaluator input with projection date, as-of date, and bounded journal events.
- Added a completion callback to target evaluators.
- Implemented fixed target completion inside Improve.Planning.Targets.Fixed, including progress details and completed linked events.
- Moved projected track completion away from the projector shortcut and through Improve.Planning.Targets.completion/2 while preserving existing planned, completed, missed, and time-off behavior.
- Added focused fixed-target completion tests.

Verification:

- mix test test/improve/planning/targets/fixed_test.exs test/improve/planning/project_today_test.exs
- mise run verify:backend
