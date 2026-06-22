---
# improve-ash-mxsx
title: Design projected work output for sessions and direct goals
status: completed
type: task
priority: high
created_at: 2026-06-22T21:37:54Z
updated_at: 2026-06-22T22:18:21Z
parent: improve-ash-lde6
---

Define the projection output shape that can represent session occurrences, direct goal targets, target status, explanations, and diagnostics without forcing direct goals through a session wrapper. Acceptance: design captured in code/docs and tests can describe both variants.



Completed:
- Added Improve.Planning.ProjectedWork as the typed projected-work value shape for sessions and direct goals.
- project_today now returns projected_work alongside projected_session_occurrences for backwards compatibility.
- AshAI project_today JSON now includes projected_work.
- Added notes/projection-output.md documenting the shape and non-mutating projection boundary.
- Added tests for session projected work, direct goal projected work, project_today compatibility, and AI serialization.
- mise run verify passes.
