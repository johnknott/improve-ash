---
# improve-ash-4e0i
title: Regenerate contracts after Track rename
status: completed
type: task
priority: normal
tags:
    - backend
    - contracts
created_at: 2026-06-24T12:15:06Z
updated_at: 2026-06-24T12:25:14Z
parent: improve-ash-qvk7
blocked_by:
    - improve-ash-rx90
---

## Context

The AshTypescript surface should expose Track vocabulary once the backend rename lands.

## Tasks

- [x] Update AshTypescript-exposed resources/actions after the Track rename.
- [x] Regenerate `priv/generated/ash_types.ts` and `priv/generated/ash_rpc.ts`.
- [x] Update TypeScript smoke tests for track names.
- [x] Remove generated DirectGoal contract references.

## Acceptance

- [x] `mise run typescript:generate` and `mise run typescript:check` pass after the rename.

## Summary of Changes

Regenerated AshTypescript contracts after the Track rename, confirmed no generated DirectGoal/direct_goal references remain, and added a TypeScript smoke assertion for `EventInstanceResourceSchema.trackId`. Verified with `mise run typescript:generate`, `mix ash_typescript.codegen --check`, `mise run typescript:check`, `mix compile --warnings-as-errors`, and `mise run test`.
