---
# improve-ash-nzzr
title: Implement every-N-weeks schedule projection
status: todo
type: task
priority: high
created_at: 2026-06-25T09:54:58Z
updated_at: 2026-06-25T09:55:24Z
parent: improve-ash-aszg
---

Add an every_n_weeks schedule evaluator using interval weeks plus selected weekdays. It should mirror the existing every_n_days and selected_weekdays evaluator style, respect starts_on/ends_on via the projector, and include track/session projection tests.
