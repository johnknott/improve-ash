---
# improve-ash-zkg7
title: Internal evaluator framework probe
status: todo
type: milestone
priority: high
created_at: 2026-06-24T20:37:19Z
updated_at: 2026-06-24T20:37:19Z
---

Build the first internal-only evaluator framework slice from notes/extension-points-plan.md.

This milestone is intentionally boring and pre-marketplace: prove the evaluator shape inside Improve.Planning before exposing anything as a public extension API.

Acceptance criteria:
- The current schedule projection behavior is preserved.
- Schedule dispatch moves behind a small internal evaluator contract.
- Diagnostics remain plain-English and at least as useful as today.
- A second evaluator kind is considered only after the schedule extraction proves the shape.
- Capability/dependency graph machinery is added only when a real evaluator dependency exists.
- No database writes, clock reads, HTTP calls, randomness, or journal mutation happen inside evaluators.
