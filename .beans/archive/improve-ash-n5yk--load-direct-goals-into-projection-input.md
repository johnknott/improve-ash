---
# improve-ash-n5yk
title: Load direct goals into projection input
status: completed
type: task
priority: high
created_at: 2026-06-22T21:37:54Z
updated_at: 2026-06-22T22:20:07Z
parent: improve-ash-lde6
blocked_by:
    - improve-ash-mxsx
---

Update the projection boundary to fetch direct goals and their schedules/targets alongside session templates. Acceptance: project_today input includes direct goals without mutating history and existing gym projection remains green.



Completed:
- Plans.project_today/2 now fetches direct goals into the projection input.
- Projector returns input_summary counts including direct goals and direct-goal schedules.
- AshAI project_today JSON includes input_summary.
- Added coverage proving a direct-goal schedule reaches projection input without creating sessions or journal events.
- Existing gym projection remains green and mise run verify passes.
