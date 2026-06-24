---
# improve-ash-z91i
title: Harden the evaluator contract with a second kind
status: completed
type: epic
priority: normal
created_at: 2026-06-24T20:37:34Z
updated_at: 2026-06-24T20:52:48Z
parent: improve-ash-zkg7
---

After the schedule probe proves the shape, use one additional evaluator kind to harden the internal contract.

Likely candidate: target diagnostics, because the current code already has implemented, recognized-unsupported, and unknown tiers similar to schedules.

Do not start this until schedule evaluators feel lighter than the cond they replaced.

## Summary of Changes

Completed the second evaluator-kind pass.

What changed:
- Confirmed target diagnostics as the second evaluator kind after the schedule probe.
- Added `Improve.Planning.Targets` as an internal target diagnostic dispatcher.
- Added `Targets.Evaluation`, `Targets.Evaluator`, and `Targets.Fixed`.
- Moved missing target, implicit target, fixed target, recognized-unsupported target, and unknown target diagnostics out of `Improve.Planning.Projector`.
- Added characterization coverage for unknown target types.
- Added explicit internal types/specs for schedule and target evaluator input/result shapes without introducing a generic public result struct.
- Reviewed namespace direction and kept the evaluator code in planning-specific internal namespaces rather than moving to a broad extension namespace.

Verification:
- `mix test test/improve/planning/project_today_test.exs` passed.
- `mix test test/improve/planning/project_today_test.exs test/improve/app_test.exs test/improve/stories/stories_test.exs` passed.
- `mix compile --warnings-as-errors` passed.
- `mise run verify:backend` passed.
- `git diff --check` passed.
