---
# improve-ash-tjpx
title: Story note and first direct-goal script
status: completed
type: feature
priority: high
created_at: 2026-06-23T06:57:51Z
updated_at: 2026-06-23T06:59:01Z
parent: improve-ash-qdoa
---

Document the plain-English product story script idea, add a thin Improve.Stories helper layer, and land the first executable direct-goal story script.

Todo:
- [x] Add `notes/product-story-scripts.md` as project input.
- [x] Add a thin `Improve.Stories` helper layer for story setup, direct goals, logging, and printing.
- [x] Add the first executable direct-goal story under `priv/scripts/stories/`.
- [x] Add focused coverage and run verification.

## Summary of Changes

- Added `notes/product-story-scripts.md` as a project input describing the purpose, shape, reset behavior, naming principles, and future story flows.
- Added a thin `Improve.Stories` helper layer with story context, scoped reset, direct-goal creation/logging helpers, schedule helpers, and printing helpers.
- Added `priv/scripts/stories/01_direct_goal_reading.exs`, an executable direct-goal reading story.
- Added focused test coverage for the direct-goal story helpers and story-key reset behavior.
- Verified the actual story script with `mix run priv/scripts/stories/01_direct_goal_reading.exs` after migrating the dev DB.
- Final verification: `mise run verify` passed with 92 tests and TypeScript checking.
