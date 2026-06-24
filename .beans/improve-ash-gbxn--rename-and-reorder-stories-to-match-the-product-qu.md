---
# improve-ash-gbxn
title: Rename and reorder stories to match the product question set
status: done
type: task
priority: normal
tags:
    - backend
    - stories
created_at: 2026-06-24T12:16:53Z
updated_at: 2026-06-24T13:10:42Z
parent: improve-ash-qtdm
blocked_by:
    - improve-ash-sdqf
    - improve-ash-igl6
    - improve-ash-ooye
---

## Context

The story filenames should guide development through product questions, not through old implementation history.

## Tasks

- [x] Rename/reorganize scripts toward `01_track_reading`, `02_track_target_types`, `03_schedule_shapes`, `04_session_from_pools`, `05_adaptive_item_work`, `06_stateful_item_effects`, `07_offline_and_correction`, `08_review_and_adjustment`, and `09_full_life_plan`.
- [x] Update story docs and tests for new names.
- [x] Keep each script focused on one product question.

## Acceptance

- [x] `priv/scripts/stories/` reads like the recommended story set from the plan note.
