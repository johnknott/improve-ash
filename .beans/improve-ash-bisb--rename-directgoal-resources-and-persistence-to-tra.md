---
# improve-ash-bisb
title: Rename DirectGoal resources and persistence to Track
status: completed
type: task
priority: high
tags:
    - backend
    - track
created_at: 2026-06-24T12:14:39Z
updated_at: 2026-06-24T12:22:55Z
parent: improve-ash-qvk7
---

## Context

Perform the core rename without preserving data compatibility. This should be a clean prototype rename, not a migration-support project.

## Tasks

- [x] Rename `Improve.Plans.DirectGoal` to `Improve.Plans.Track`.
- [x] Rename direct-goal attributes, relationships, actions, code interfaces, and policies to track language.
- [x] Replace direct-goal database tables/columns/migrations with track equivalents suitable for a fresh prototype database.
- [x] Update seeds/fixtures to build tracks directly.
- [x] Remove obsolete DirectGoal modules and references.

## Acceptance

- [x] `rg "DirectGoal|direct_goal" lib priv test` shows only intentional historical notes, if any.

## Summary of Changes

Renamed the backend Ash resource, table, relationships, journal references, schedules, fixtures, tests, generated types, and story script path from DirectGoal/direct_goal to Track/track for the fresh prototype schema. Verified with `mix compile`, `rg "DirectGoal|direct_goal" lib priv test`, and `mise run test` after recreating the test database.
