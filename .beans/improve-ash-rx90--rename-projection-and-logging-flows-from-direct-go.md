---
# improve-ash-rx90
title: Rename projection and logging flows from direct goals to tracks
status: completed
type: task
priority: high
tags:
    - backend
    - track
created_at: 2026-06-24T12:15:00Z
updated_at: 2026-06-24T12:24:06Z
parent: improve-ash-qvk7
blocked_by:
    - improve-ash-bisb
---

## Context

Track language must flow through the planning and journal paths, not only the resource name.

## Tasks

- [x] Rename projected work kinds and structs/maps from direct goal to track.
- [x] Rename `log_direct_goal` flows to `log_track`.
- [x] Rename event/journal references such as `direct_goal_id` to track language.
- [x] Update Today/App/AiContext helpers to return track vocabulary.
- [x] Update tests for projection, logging, AI context, and ownership boundaries.

## Acceptance

- [x] A simple track can be projected and logged without any DirectGoal API or output.

## Summary of Changes

Updated projected work, journal logging, App/Story calls, AI context, plan drafts, scripts, and tests to use Track vocabulary all the way through. `log_track!` now accepts `track:` instead of the old goal-shaped input. Verified with `rg` for old goal/direct-goal language in backend/story surfaces, `mix compile --warnings-as-errors`, and `mise run test`.
