---
# improve-ash-8qr7
title: Extract schedule evaluators internally
status: completed
type: epic
priority: high
created_at: 2026-06-24T20:37:34Z
updated_at: 2026-06-24T20:45:58Z
parent: improve-ash-zkg7
---

Move schedule projection dispatch out of the Projector cond and behind a small internal evaluator shape.

Keep this narrowly scoped to schedules and preserve existing behavior before generalizing.

Done when schedule evaluators are internal, tested, and no broader extension framework has been introduced prematurely.

## Summary of Changes

Completed the internal schedule evaluator extraction.

What changed:
- Added characterization tests for selected weekdays, malformed every-N-days rules, and unknown schedule kinds.
- Added an internal `Improve.Planning.Schedules` dispatcher, `Evaluation` struct, and `Evaluator` behaviour.
- Extracted implemented schedule kinds into internal modules for every day, selected weekdays, every N days, and times per week.
- Moved recognized-unsupported and unknown schedule diagnostics into dispatcher support tiers.
- Simplified `Improve.Planning.Projector` so schedule-specific decision logic lives behind `Schedules.decide/3`.
- Documented the probe review in `improve-ash-9oig`: continue cautiously, with target diagnostics as the likely next narrow evaluator candidate, and defer capability graph machinery until a real dependency exists.

Verification:
- `mix test test/improve/planning/project_today_test.exs` passed.
- `mix compile --warnings-as-errors` passed.
- `mix test test/improve/app_test.exs test/improve/stories/stories_test.exs test/improve/planning/project_today_test.exs test/improve/planning/diagnostics_test.exs` passed.
- `mise run verify:backend` passed.
- `git diff --check` passed.
