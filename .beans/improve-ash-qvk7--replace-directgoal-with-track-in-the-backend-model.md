---
# improve-ash-qvk7
title: Replace DirectGoal with Track in the backend model
status: completed
type: epic
priority: high
tags:
    - backend
    - story-api
created_at: 2026-06-24T12:14:27Z
updated_at: 2026-06-24T12:25:27Z
parent: improve-ash-qdoa
---

## Context

We have no users or migration burden, so Track should become the real backend model now instead of adding a compatibility layer around DirectGoal. Remove DirectGoal naming from resources, persistence, projections, logging, stories, tests, generated contracts, and user-facing output.

## Acceptance

- [x] Backend resources/actions/modules use Track/track naming instead of DirectGoal/direct_goal.
- [x] Product-facing APIs and story output contain no direct_goal language.
- [x] Tests cover track projection and logging through the renamed model.
- [x] Compatibility aliases/shims are removed rather than preserved.

## Summary of Changes

Completed the backend Track rename across Ash resources, fresh schema migrations/snapshots, projection, logging, journal references, story scripts, tests, and generated TypeScript contracts. The old DirectGoal/direct_goal vocabulary is removed from `lib`, `priv`, and `test` surfaces, and the new `log_track!` path uses `track:` input. Verified with compiler, tests, contract generation, TypeScript checks, and search.
