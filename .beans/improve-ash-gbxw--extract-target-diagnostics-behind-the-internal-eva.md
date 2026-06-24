---
# improve-ash-gbxw
title: Extract target diagnostics behind the internal evaluator shape
status: completed
type: task
priority: normal
created_at: 2026-06-24T20:38:19Z
updated_at: 2026-06-24T20:51:09Z
parent: improve-ash-z91i
blocked_by:
    - improve-ash-8qr7
---

If target diagnostics are chosen as the second kind, move implemented, recognized-unsupported, and unknown target handling behind the same internal evaluator style.

Preserve product-facing diagnostics and story output.

Done when target diagnostics prove whether the schedule evaluator shape generalizes cleanly.

## Summary of Changes

Extracted target projection diagnostics from `Improve.Planning.Projector` into an internal `Improve.Planning.Targets` namespace.

What changed:
- Added `Improve.Planning.Targets` as the internal dispatcher for target diagnostic support tiers.
- Added `Targets.Evaluation`, `Targets.Evaluator`, and a `Targets.Fixed` evaluator.
- Preserved missing target, implicit target, fixed target, recognized-unsupported target, and unknown target behavior.
- Added characterization coverage for unknown target types.
- Kept the scope to diagnostics only; this does not implement target completion evaluation or a public extension API.

Focused verification passed with `mix test test/improve/planning/project_today_test.exs test/improve/app_test.exs test/improve/stories/stories_test.exs` and `mix compile --warnings-as-errors`.
