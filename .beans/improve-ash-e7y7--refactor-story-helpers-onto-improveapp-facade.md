---
# improve-ash-e7y7
title: Refactor story helpers onto Improve.App facade
status: completed
type: task
priority: normal
created_at: 2026-06-23T22:31:59Z
updated_at: 2026-06-23T22:37:41Z
---

Make backend story scripts/tests exercise product-facing Improve.App operations rather than keeping business behavior in Improve.Stories helpers where a stable app facade belongs.

- [x] Compare Improve.Stories helper surface with Improve.App facade
- [x] Move suitable story operations into Improve.App or delegate through existing App functions
- [x] Update story tests/scripts only where the public story DSL should change
- [x] Run focused backend tests

## Summary of Changes

- Added `Improve.App.add_exercise!/3` as the app-facing convenience for creating exercise items.
- Reduced `Improve.Stories.add_exercise!/4` to a thin wrapper around `Improve.App`.
- Refactored executable story scripts so `Story` handles setup/output while product operations call `Improve.App` with an explicit actor.
- Updated the product story note to document the new App-first script shape.

Verified with:

- `mix run priv/scripts/stories/*.exs` via a shell loop
- `mix test test/improve/app_test.exs test/improve/stories/stories_test.exs`
