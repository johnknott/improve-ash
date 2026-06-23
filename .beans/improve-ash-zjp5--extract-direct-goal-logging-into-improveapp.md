---
# improve-ash-zjp5
title: Extract direct-goal logging into Improve.App
status: completed
type: task
priority: normal
created_at: 2026-06-23T07:28:17Z
updated_at: 2026-06-23T07:28:17Z
parent: improve-ash-qdoa
---

Introduce a small Improve.App facade for the direct-goal logging workflow discovered by story scripts, and make Improve.Stories call it instead of owning that app-facing operation.

Summary:
- Added Improve.App.log_direct_goal!/2 for the UI-shaped direct-goal logging workflow.
- Updated Improve.Stories.log_direct_goal!/3 to delegate to Improve.App.
- Added direct App coverage for deriving event type, quantity, unit, note, and summary from the goal payload/target metadata.
