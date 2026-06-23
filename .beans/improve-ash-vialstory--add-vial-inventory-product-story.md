---
# improve-ash-vialstory
title: Add vial inventory product story
status: completed
type: task
priority: normal
created_at: 2026-06-23T08:20:00Z
updated_at: 2026-06-23T08:20:00Z
parent: improve-ash-qdoa
---

Add an executable product story for stateful inventory logging: create a vial,
define a generic linked-item event type with an authored subtract-quantity
effect, log the event through the app-facing API, show journal and derived item
state, and cover the behavior with a story spec.

Summary:
- Added `priv/scripts/stories/03_log_dose_and_check_vial_state.exs`.
- Added generic `Improve.App.log_event!/2` and `Improve.App.get_item_state!/3`.
- Added story helpers for authored quantity effects, generic event logging, item state output, and AI item state output.
- Covered event, item link, generated item effect, derived quantity, journal, and AI item state in the story spec.
