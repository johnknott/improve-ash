---
# improve-ash-leiw
title: Update target and schedule stories for V1 support
status: completed
type: task
priority: normal
created_at: 2026-06-25T09:55:03Z
updated_at: 2026-06-25T10:43:24Z
parent: improve-ash-aszg
blocked_by:
    - improve-ash-w5pw
    - improve-ash-hawh
    - improve-ash-e7vd
    - improve-ash-x3yd
    - improve-ash-mdo6
    - improve-ash-c4j1
    - improve-ash-nzzr
---

Rewrite or extend 02_track_target_types.exs and 03_schedule_shapes.exs so they prove real V1 completion/progress and monthly/every-N-weeks support. after_completion and custom should remain visible as recognized-but-unsupported with clean diagnostics. Add/adjust automated story or projection assertions so the story output stays honest.

- Summary of Changes: Updated the target story to prove all six V1 target shapes progress from planned to completed, updated the schedule story to show every-N-weeks/monthly support plus clean after-completion/custom unsupported diagnostics, and extended automated story assertions. Aligned checklist completion with the authored checked_items payload field. Verified with focused story/script runs and full `mise run verify:backend`.
