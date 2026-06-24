---
# improve-ash-t41l
title: Rewrite session authoring around generic pools and slots
status: completed
type: task
priority: normal
tags:
    - backend
    - sessions
created_at: 2026-06-24T12:15:54Z
updated_at: 2026-06-24T12:39:24Z
parent: improve-ash-xqim
---

## Context

Session stories should not require gym words in the core API. Domain-specific examples can exist as fixtures, but the platform language should be item/pool/slot/session.

## Tasks

- [x] Ensure App/Story helpers can add items, pools, environments, sessions, and slots generically.
- [x] Replace domain-specific runtime helper names with generic equivalents.
- [x] Update fixture code so gym/vial naming lives in fixture content, not core API.
- [x] Add tests for generic session authoring.

## Acceptance

- [x] A generic session story can choose items from a named pool without gym-specific API calls.

## Summary of Changes

Removed the domain-specific `add_exercise!` helper from `Improve.App` and `Improve.Stories`, replaced story/test call sites with generic `add_item_type!` and `add_item!`, and verified the session story still authors items, pools, slots, recommendations, swaps, and logs through generic primitives. Domain-specific exercise language remains only as authored demo content. Verified with `mise run test`, the session story under `MIX_ENV=test`, AshTypescript codegen check, TypeScript check, and `rg add_exercise!`.
