---
# improve-ash-9oig
title: Review the schedule evaluator probe before generalizing
status: completed
type: task
priority: high
created_at: 2026-06-24T20:38:19Z
updated_at: 2026-06-24T20:45:35Z
parent: improve-ash-8qr7
---

Pause after schedule extraction and decide whether the internal evaluator shape earned its keep.

Document what got simpler, what got heavier, and what should change before target diagnostics or dependency graph work starts.

Done when notes or bean summary clearly say whether to continue, adjust, or scrap the evaluator direction.

## Summary of Changes

Reviewed the schedule evaluator probe after extraction. The internal shape earned its keep for schedules:

- `Projector` is now smaller and focused on projection flow rather than per-kind schedule rules.
- Implemented schedule kinds are isolated in modules with explicit `schedule/date/input` evaluation.
- Support tiers are clearer in one dispatcher: implemented, recognized unsupported, and unknown.
- The shape stayed internal under `Improve.Planning.Schedules`; it does not yet imply a public extension API.
- The main new weight is a handful of modules and a small helper module, which feels acceptable because times-per-week quota logic was already substantial.

Recommendation before generalizing: continue, but keep the next step similarly narrow. Target diagnostics are still the best second evaluator candidate, but do not add capability graph machinery until a real evaluator dependency appears.

Verification:
- `mix test test/improve/planning/project_today_test.exs` passed.
- `mix compile --warnings-as-errors` passed.
- `mix test test/improve/app_test.exs test/improve/stories/stories_test.exs test/improve/planning/project_today_test.exs test/improve/planning/diagnostics_test.exs` passed.
- `mise run verify:backend` passed.
