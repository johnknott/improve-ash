---
# improve-ash-97ij
title: Prove the contract with an adaptive marathon plan
status: completed
type: epic
priority: normal
created_at: 2026-06-24T20:37:34Z
updated_at: 2026-06-25T03:55:00Z
parent: improve-ash-zkg7
---

Use a credible adaptive marathon training plan as the forcing example for the evaluator contract.

The plan should separate declarative structure, one-time baseline customization, derived adaptation, and committed plan edits.

This remains draft until the internal evaluator contract has survived smaller schedule and target work.

## Ready

The internal schedule and target evaluator probes are complete. This epic is now ready to begin with the product-story draft, still backend-only and product-first. Capability graph work remains deferred until the marathon story reveals a real evaluator dependency.

## Summary of Changes

The adaptive marathon forcing example now proves the internal evaluator
contract end to end, backend-only:

- Declarative structure: the marathon plan is ordinary plans, tracks, schedules,
  journal events, item effects, and time-off windows.
- Layer 2 customization: baseline 5k pace derivation writes auditable static
  track guidance once.
- Derived metrics: `recent_load_km` is computed by a hermetic evaluator from
  bounded projection input.
- Dependency graph: the host orders `recent_load_metric -> marathon_adaptation`,
  caches the metric output, and injects it into the consumer.
- Derived adaptation: missed quality, illness, injury, and holiday re-entry
  produce no-write projection-time proposals.
- Committed adaptation: approval-required proposed edits are separate from
  derived proposals.
- Story verification: `10_adaptive_marathon.exs` now runs Layer 3 through the
  real evaluator contract and prints derived and committed proposal language.

Verification passed with `mise run verify:backend`.
