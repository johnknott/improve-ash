---
# improve-ash-04lo
title: Project today with pure planner and deterministic recommendations
status: completed
type: task
priority: high
tags:
    - planning
    - gym
created_at: 2026-06-22T19:52:11Z
updated_at: 2026-06-22T20:39:54Z
parent: improve-ash-o8x1
---

## Plan

- [x] Re-read project_today and pure planner requirements from the spike spec.
- [x] Add pure Planning.Recommender for deterministic slot item recommendations.
- [x] Add pure Planning.Projector for date-based session projection without persistence.
- [x] Add Plans.project_today/2 as a thin Ash-loading boundary around the pure projector.
- [x] Add scenario tests using the gym fixture, including no database mutation.
- [x] Run verification and close the bean.

## Completed

- Added Improve.Planning.Recommender for deterministic pool/environment-based item recommendations.
- Added Improve.Planning.Projector for pure date-based session projection.
- Added Plans.project_today/2 and project_today!/2 as thin loaders around the pure projector.
- Supports every_day, selected_weekdays, and simple times_per_week schedules.
- Returns projected session occurrences, slot recommendations, diagnostics, and explanations.
- Added gym projection tests proving recommendations and no SessionOccurrence persistence.
- Verified with mise run verify and mix ash_postgres.generate_migrations --check.
