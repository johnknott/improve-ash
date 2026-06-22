---
# improve-ash-5b9d
title: Add schedule diagnostics for unplaceable work
status: completed
type: task
priority: normal
created_at: 2026-06-22T21:37:54Z
updated_at: 2026-06-22T22:27:43Z
parent: improve-ash-lde6
blocked_by:
    - improve-ash-avt7
---

Produce plain-English diagnostics when schedules cannot be fully projected. Acceptance: tests cover impossible quotas, missing targets, unsupported schedule shapes, and partially placeable work.



Completed:
- Projector can now carry diagnostics alongside successful projections.
- Added plain-English diagnostics for impossible quota schedules, unsupported schedule rule shapes, missing direct goal targets, unsupported schedule kinds, and partially placeable quota schedules.
- Added tests for impossible quotas, missing targets, unsupported schedule shapes, and partial placement.
- mise run verify passes.
