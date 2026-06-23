---
# improve-ash-rqfp
title: Tidy direct-goal story logging ergonomics
status: completed
type: task
priority: normal
created_at: 2026-06-23T07:19:03Z
updated_at: 2026-06-23T07:19:03Z
parent: improve-ash-qdoa
---

Make the first direct-goal story read more like the product by deriving the goal event type and reducing duplicate log attributes without adding a magical DSL.

Todo:
- [x] Derive direct-goal log event type from the goal by default.
- [x] Derive quantity/unit/note from payload plus simple goal target metadata.
- [x] Update the first story and focused tests to use the tidier call.
- [x] Run the story script and full verification.

## Summary of Changes

- `Story.log_direct_goal!/3` now uses the direct goal's event type by default, with `:event`/`:as_event` still available as explicit overrides.
- Direct-goal logs can derive journal `quantity`, `unit`, `note`, and summary from payload plus simple target metadata (`quantity_path`, `unit`, `summary_template`).
- Updated the first reading story and project note so the log call only needs `goal:` and `payload:` for the common case.
- Verified the executable story with `mix run priv/scripts/stories/01_direct_goal_reading.exs`.
- Final verification: `mise run verify` passed with 92 tests and TypeScript checking.
