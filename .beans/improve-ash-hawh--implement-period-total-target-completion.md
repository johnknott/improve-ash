---
# improve-ash-hawh
title: Implement period-total target completion
status: todo
type: task
priority: high
created_at: 2026-06-25T09:54:47Z
updated_at: 2026-06-25T09:55:17Z
parent: improve-ash-aszg
blocked_by:
    - improve-ash-xkgr
---

Period-total targets complete when summed logged quantity across the relevant week/month reaches the target amount. The evaluator should compute the period containing the projection date, return progress such as 18 of 25 pages this week, and avoid hidden database or clock access.
