---
# improve-ash-38rj
title: Add minimal capability descriptors for real inputs
status: completed
type: task
priority: normal
created_at: 2026-06-24T20:38:31Z
updated_at: 2026-06-25T00:45:00Z
parent: improve-ash-o1ro
blocked_by:
    - improve-ash-z91i
---

Define the smallest capability descriptor shape needed by an actual evaluator dependency.

Capabilities should describe required inputs and prior evaluator outputs without handing evaluators the whole world.

Done when host input assembly is explicit, bounded, and testable.

## Ready

Ready after h81d identified the concrete dependency: the marathon adaptation
evaluator consumes `recent_load_km`, which is produced by a separate
derived-metric evaluator.

## Checklist

[x] Add a minimal descriptor shape for evaluator `provides` and `requires`.
[x] Declare the two marathon descriptors from the h81d note.
[x] Expose the concrete producer-to-consumer dependency without adding ordering
or execution machinery.
[x] Add focused tests for bounded inputs and dependency visibility.
[x] Run backend verification.

## Summary of Changes

Added `Improve.Planning.EvaluatorCapabilities` as a minimal data-only
capability descriptor module. It declares the concrete marathon descriptors
from h81d: `recent_load_metric` provides `recent_load_km`, while
`marathon_adaptation` requires `recent_load_km` plus explicit bounded projection
inputs such as projected work, life events, time-off windows, plan skeleton, and
track guidance.

The module also exposes provider indexing and dependency-edge discovery so the
host can see the real `recent_load_metric -> marathon_adaptation` dependency.
It deliberately does not order, cache, or run evaluators; that remains the
scope of `improve-ash-44nx`.

Added focused tests for the descriptor shape, bounded inputs, provider lookup,
and the single visible dependency edge. Verification passed with
`mise run verify:backend`.
