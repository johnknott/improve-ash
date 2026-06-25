---
# improve-ash-mdo6
title: Implement adaptive target completion
status: completed
type: task
priority: high
created_at: 2026-06-25T09:54:57Z
updated_at: 2026-06-25T10:32:30Z
parent: improve-ash-aszg
blocked_by:
    - improve-ash-xkgr
---

For standalone adaptive tracks, logging an event with the configured adaptive fields counts as done for that date. This is the completion side only; smart suggested payloads remain in recommender/session logic. Include tests that adaptive projection no longer emits unsupported-target diagnostics once implemented.

## Summary of Changes

- Added an adaptive target evaluator for standalone adaptive tracks.
- Adaptive completion now checks same-day linked journal events for the configured fields plus configured effort field.
- Progress reports required, recorded, and missing adaptive fields.
- Removed adaptive from the unsupported target list, so all V1 target shapes now project through target evaluators.
- Updated the stale target diagnostic test to cover unknown target types instead of unsupported V1 shapes.

Verification:

- mix test test/improve/planning/targets test/improve/planning/project_today_test.exs test/improve/app_test.exs test/improve/stories/stories_test.exs
- mise run verify:backend
