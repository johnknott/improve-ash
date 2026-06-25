---
# improve-ash-o1ro
title: Add capability resolution only when needed
status: completed
type: epic
priority: normal
created_at: 2026-06-24T20:37:34Z
updated_at: 2026-06-25T02:05:00Z
parent: improve-ash-zkg7
---

Introduce capability descriptors, evaluator dependencies, ordering, and caching only when a real second-order evaluator dependency exists.

The goal is to avoid speculative graph machinery while preserving the architecture needed for adaptation and derived metrics later.

## Summary of Changes

Capability resolution was added only after the adaptive marathon plan forced a
real evaluator dependency. The completed child beans now cover the full intended
slice:

- `improve-ash-h81d`: identified marathon adaptation consuming
  `recent_load_km` as the first real dependency.
- `improve-ash-38rj`: added minimal data-only capability descriptors with
  `provides` and `requires`.
- `improve-ash-44nx`: added a tiny graph host that orders the two-node chain,
  caches declared outputs once per projection run, and injects cached outputs
  into downstream evaluator input.

This remains intentionally internal and narrow: no public extension namespace,
general registry, plugin loading, versioning, sandboxing, persistence, or UI.
