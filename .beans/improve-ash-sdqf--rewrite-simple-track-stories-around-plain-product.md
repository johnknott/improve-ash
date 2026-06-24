---
# improve-ash-sdqf
title: Rewrite simple track stories around plain product language
status: completed
type: task
priority: normal
tags:
    - backend
    - stories
created_at: 2026-06-24T12:15:39Z
updated_at: 2026-06-24T12:36:21Z
parent: improve-ash-vl5b
blocked_by:
    - improve-ash-rx90
    - improve-ash-4ib0
---

## Context

The first stories should become the standard for how the backend API wants to be used by a future UI.

## Tasks

- [x] Replace the direct-goal reading story with a track-based reading story.
- [x] Add or update a target-types story covering friendly target constructors.
- [x] Keep story helpers thin wrappers around `Improve.App`.
- [x] Update story specs to assert behavior, not just script execution.

## Acceptance

- [x] The simple track story reads like: create plan, add track, project today, log track, show journal/context.

## Summary of Changes

Rewrote the first reading story around `App.add_track!`, `fixed/2`, `number/1`, inferred event types, `project_today!`, `log_track!`, journal output, and AI context. Added `02_track_target_types.exs` and story specs that assert constructor-backed behavior and target diagnostics. Verified with `mise run test`, both story scripts under `MIX_ENV=test`, AshTypescript codegen check, TypeScript check, and old-vocabulary search.
