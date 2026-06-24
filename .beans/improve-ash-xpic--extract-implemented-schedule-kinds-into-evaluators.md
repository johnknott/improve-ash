---
# improve-ash-xpic
title: Extract implemented schedule kinds into evaluators
status: completed
type: task
priority: high
created_at: 2026-06-24T20:38:06Z
updated_at: 2026-06-24T20:44:25Z
parent: improve-ash-8qr7
---

Move the implemented schedule branches out of Projector.schedule_applies?/3 and into internal evaluator modules.

Preserve behavior for daily, selected weekdays, every N days, times per week, every N weeks, monthly, and any other implemented shapes.

Done when Projector delegates schedule decisions through the internal dispatcher and existing tests still pass.

## Summary of Changes

Extracted implemented schedule kinds into internal evaluator modules: every day, selected weekdays, every N days, and times per week. The times-per-week quota placement logic moved with its evaluator instead of remaining inside the main Projector.
