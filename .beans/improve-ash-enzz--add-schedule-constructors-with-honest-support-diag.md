---
# improve-ash-enzz
title: Add schedule constructors with honest support diagnostics
status: completed
type: task
priority: high
tags:
    - backend
    - schedules
created_at: 2026-06-24T12:15:26Z
updated_at: 2026-06-24T12:32:33Z
parent: improve-ash-vl5b
---

## Context

The story API should expose the intended schedule vocabulary even when some schedule shapes are recognized but not fully projected yet.

## Tasks

- [x] Add constructors for `every_day`, `selected_weekdays`, `every_n_days`, `times_per_week`, `every_n_weeks`, `monthly`, `after_completion`, and `custom`.
- [x] Project supported schedule shapes for tracks and sessions.
- [x] Return plain-English diagnostics for recognized-but-unsupported and invalid schedules.
- [x] Add schedule coverage tests and a schedule story.

## Acceptance

- [x] Stories can tell the difference between supported, recognized but unsupported, and invalid schedule shapes.

## Summary of Changes

Expanded product-facing schedule constructors, exposed them through `Improve.App` and `Improve.Stories`, added `every_n_days` projection, and added recognized-but-not-supported projection diagnostics for monthly/every-N-weeks/after-completion/custom schedules. Added schedule constructor/projection tests and the `03_schedule_shapes.exs` story. Verified with `mise run test`, the schedule story under `MIX_ENV=test`, AshTypescript codegen check, TypeScript check, and old-vocabulary search.
