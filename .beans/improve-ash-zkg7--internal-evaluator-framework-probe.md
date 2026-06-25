---
# improve-ash-zkg7
title: Internal evaluator framework probe
status: completed
type: milestone
priority: high
created_at: 2026-06-24T20:37:19Z
updated_at: 2026-06-25T03:55:00Z
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

The first internal evaluator probes and the first forced dependency graph are
complete.

Completed:
- `improve-ash-8qr7`: schedule projection dispatch now goes through internal `Improve.Planning.Schedules` evaluators.
- `improve-ash-z91i`: target projection diagnostics now go through internal `Improve.Planning.Targets` evaluators.
- `improve-ash-h81d`: the real evaluator dependency is documented as marathon
  adaptation consuming a recent-load derived metric.
- `improve-ash-38rj`: minimal capability descriptors declare `provides` and
  `requires` for that concrete dependency.
- `improve-ash-44nx`: a tiny graph host orders the two-node chain, caches
  derived outputs for a projection run, and injects them into the consumer.

Current architectural decision:
- Keep evaluator code boringly internal under planning-specific namespaces.
- Do not introduce a public extension namespace or marketplace/plugin framing yet.
- Use explicit typed inputs/results per evaluator kind rather than a generic shared result struct.

Capability graph status:
- Capability descriptors, dependency ordering, and evaluator output caching were
  added only after the marathon adaptation dependency forced them.
- The graph host remains deliberately small: one concrete dependency chain, no
  general registry, plugin loading, versioning, sandboxing, persistence, or UI.

Final forcing example:
- The adaptive marathon plan now runs through the internal evaluator contract:
  recent-load derivation, dependency ordering/caching, derived adaptation,
  committed proposal separation, and story verification are complete.

## Summary of Changes

The internal evaluator framework probe is complete. Schedule dispatch and target
diagnostics use small internal evaluator contracts; capability descriptors,
dependency graph ordering, and output caching were added only after the
marathon plan forced a real evaluator dependency. The marathon story then proved
the contract with a real derived metric and adaptation consumer, while keeping
all evaluator code hermetic: no database writes, clock reads, HTTP calls,
randomness, AI, or journal mutation.

UI policy:
- UI authoring work is deferred until the backend/product model is substantially complete.
