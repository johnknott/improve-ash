---
# improve-ash-f7jj
title: Slim mutation responses
status: completed
type: task
priority: normal
created_at: 2026-07-04T13:20:04Z
updated_at: 2026-07-04T19:32:11Z
parent: improve-ash-fd57
---

Every write returns the full dashboard. Return the affected slice or add a delta/changed-since mechanism. (notes/fable-todo.md item #14)

## Summary of Changes

Chose the slice model over changed-since deltas (simpler, stateless, and
the dashboard payload already had natural slice boundaries).

- `build_dashboard_payload/5` takes a slice list
  (`:plans/:currentPlan/:today/:journal/:planDetail`); response keys are
  present only for requested slices, and the queries behind unrequested
  slices are skipped — notably the unbounded journal + item-links +
  item-effects reads and the plans list.
- Mutation slice map: plan-shaped ops (create/update plan, create track,
  install demo) → plans/currentPlan/today/planDetail (no journal); session
  ops (start/log/swap/complete/skip) → today/journal only; linked-event
  log/correct → today/journal/planDetail. GET /app/dashboard returns all
  slices. `/app/log-event` keeps its minimal `{event}` response.
- Frontend: `DashboardPatch` type; `appState.setDashboardData` now merges
  patches into the cached dashboard instead of replacing it.
- Test: plan update has no journal key, session start has no
  plans/planDetail keys, dashboard has all five.

Follow-up candidates (not in scope): journal pagination lands in
improve-ash-33hn; a changed-since cursor can layer on later for mobile.
