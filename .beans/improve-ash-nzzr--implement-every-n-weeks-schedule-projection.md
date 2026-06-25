---
# improve-ash-nzzr
title: Implement every-N-weeks schedule projection
status: completed
type: task
priority: high
created_at: 2026-06-25T09:54:58Z
updated_at: 2026-06-25T10:39:52Z
parent: improve-ash-aszg
---

Add an every_n_weeks schedule evaluator using interval weeks plus selected weekdays. It should mirror the existing every_n_days and selected_weekdays evaluator style, respect starts_on/ends_on via the projector, and include track/session projection tests.

- Summary of Changes: Added every_n_weeks projection using interval_weeks plus selected weekdays, registered it as implemented, refreshed supported schedule metadata in diagnostics/plan drafts, and covered track/session projection plus malformed-rule diagnostics. Updated the schedule story to show the new supported shape. Verified with focused tests and full `mise run verify:backend`.
