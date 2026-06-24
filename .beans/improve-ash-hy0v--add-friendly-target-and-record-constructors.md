---
# improve-ash-hy0v
title: Add friendly target and record constructors
status: completed
type: task
priority: high
tags:
    - backend
    - story-api
created_at: 2026-06-24T12:15:21Z
updated_at: 2026-06-24T12:29:06Z
parent: improve-ash-vl5b
---

## Context

Stories should describe what a user is trying to do, measure, improve, or remember without exposing storage schemas first.

## Tasks

- [x] Add product-facing target constructors such as `fixed/2`, `metric/2`, `checklist/1`, `period_total/3`, `progression/3`, and `adaptive/1` where they are ready.
- [x] Add record constructors such as `number/1`, `amount/1`, and `fields/1` for story/API readability.
- [x] Keep unsupported target types honest with diagnostics rather than fake behavior.
- [x] Add focused tests for constructor output and invalid target diagnostics.

## Acceptance

- [x] Story code can say `target: fixed(20, "pages")` and `records: number("pages")` for a simple track.

## Summary of Changes

Added `Improve.App.Target` constructors for fixed, metric, checklist, period-total, progression, adaptive, number, amount, and fields. Exposed them through `Improve.App` and `Improve.Stories`, taught `App.add_track!` to merge `records:` metadata into persisted targets, added unsupported target-type projection diagnostics, and rewrote the first reading story to use `fixed(20, "pages")` plus `number("pages")`. Verified with focused tests, the story script under `MIX_ENV=test`, `mise run test`, codegen check, and TypeScript check.
