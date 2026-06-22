---
# improve-ash-81ny
title: Project direct goals for a date window
status: completed
type: feature
priority: high
created_at: 2026-06-22T21:37:54Z
updated_at: 2026-06-22T22:22:35Z
parent: improve-ash-lde6
blocked_by:
    - improve-ash-mxsx
    - improve-ash-n5yk
---

Make direct goals first-class projected work. Acceptance: a reading or metric demo plan can project a due direct goal, report planned/completed/missed status from journal history, and expose the result through the headless API/AI context path.



Completed:
- Projection input now includes journal events and explicit as_of_date.
- Projector emits scheduled direct goals as first-class projected_work entries.
- Direct goal statuses are deterministic: completed from active linked journal events on the projected date, missed when date is before as_of_date without history, otherwise planned.
- Added headless API tests for planned, completed, and missed direct goal projection.
- Added AshAI project_today coverage for completed direct goal projected work.
- mise run verify passes.
