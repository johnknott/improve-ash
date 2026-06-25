---
# improve-ash-w5pw
title: Thread target completion through Projector output
status: completed
type: task
priority: high
created_at: 2026-06-25T09:54:47Z
updated_at: 2026-06-25T10:18:13Z
parent: improve-ash-aszg
blocked_by:
    - improve-ash-xkgr
---

Teach Improve.Planning.Projector to ask implemented target evaluators for completion/progress instead of deciding every track with the old any-linked-event shortcut. ProjectedWork should carry enough progress details for stories/UI serialization while preserving fallback behavior and diagnostics for missing or unknown targets.

## Summary of Changes

- Threaded target completion through Projector track work, including completion diagnostics from target evaluators.
- Added target progress to ProjectedWork track payloads.
- Exposed target progress through AshAI read-tool projection JSON as target_progress.
- Exposed target progress through Phoenix app today JSON as targetProgress.
- Added projection, projected-work, AshAI, and app-controller assertions for the progress payload.

Verification:

- mix test test/improve/planning/targets/fixed_test.exs test/improve/planning/projected_work_test.exs test/improve/planning/project_today_test.exs test/improve/ai/read_tool_test.exs test/improve_web/app_controller_test.exs
- mise run verify:backend
