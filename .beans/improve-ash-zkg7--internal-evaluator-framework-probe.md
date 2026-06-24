---
# improve-ash-zkg7
title: Internal evaluator framework probe
status: in-progress
type: milestone
priority: high
created_at: 2026-06-24T20:37:19Z
updated_at: 2026-06-24T20:57:28Z
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

## Current State

The first internal evaluator probes are complete.

Completed:
- `improve-ash-8qr7`: schedule projection dispatch now goes through internal `Improve.Planning.Schedules` evaluators.
- `improve-ash-z91i`: target projection diagnostics now go through internal `Improve.Planning.Targets` evaluators.

Current architectural decision:
- Keep evaluator code boringly internal under planning-specific namespaces.
- Do not introduce a public extension namespace or marketplace/plugin framing yet.
- Use explicit typed inputs/results per evaluator kind rather than a generic shared result struct.

Deferred until forced:
- Capability descriptors, dependency graph ordering, and evaluator output caching remain draft. They should not be implemented until a real evaluator dependency appears.

Next forcing example:
- The adaptive marathon plan remains the product test for the contract. The next backend step should be product/story-first: draft the marathon story and model declarative plan structure before implementing graph machinery.

UI policy:
- UI authoring work is deferred until the backend/product model is substantially complete.
