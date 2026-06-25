---
# improve-ash-hfm3
title: Investigate dashboard query volume on frontend navigation
status: completed
type: task
priority: normal
created_at: 2026-06-25T11:33:44Z
updated_at: 2026-06-25T11:38:34Z
---

Find why browsing frontend shell pages such as /plan causes many Ash/Postgres queries, distinguish necessary projection snapshot reads from duplicate or over-broad loads, and make a small fix if there is an obvious safe one.

- [x] Trace /plan frontend requests to Phoenix endpoints
- [x] Trace dashboard endpoint backend data loading
- [x] Measure or reason about duplicate query sources
- [x] Apply safe backend/frontend optimization if clear
- [x] Verify and summarize remaining tradeoffs

## Summary of Changes

Investigated the /plan frontend path and confirmed it uses the broad /api/app/dashboard payload. Before optimization, a measured dashboard call around the demo plan made 71 queries in the local telemetry run because the endpoint projected today, then projected the next three days separately, reloading the same plan graph each time, and then loaded plan-detail data. Added Plans.project_dates/3 and switched the dashboard to project today plus upcoming dates from one loaded projection snapshot. The same measurement now reports 32 queries. Full mise run verify is green with 223 tests.

Remaining tradeoff: the dashboard endpoint still intentionally returns Today, Journal preview, and Plan Detail in one payload. A future route-aware endpoint or scope parameter could make /plan avoid projection/journal data entirely once the Plan page becomes real.
