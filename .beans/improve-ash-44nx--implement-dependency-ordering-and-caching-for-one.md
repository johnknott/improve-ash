---
# improve-ash-44nx
title: Implement dependency ordering and caching for one real graph
status: completed
type: task
priority: normal
created_at: 2026-06-24T20:38:44Z
updated_at: 2026-06-25T01:35:00Z
parent: improve-ash-o1ro
blocked_by:
    - improve-ash-z91i
---

Once a real evaluator dependency exists, add only enough host machinery to order evaluators and cache outputs for that graph.

Avoid building a general-purpose rules engine.

Done when one concrete dependency chain runs deterministically with tests.

## Ready

Ready after `improve-ash-38rj` added minimal descriptors for the concrete
marathon dependency: `recent_load_metric -> marathon_adaptation`.

## Checklist

[x] Add minimal topological ordering from descriptor `provides`/`requires`.
[x] Add one-run capability caching and input injection.
[x] Return plain-English diagnostics for missing inputs, missing evaluator
functions, invalid evaluator results, and missing declared outputs.
[x] Prove the concrete marathon chain runs deterministically with tests.
[x] Run backend verification.

## Summary of Changes

Added `Improve.Planning.EvaluatorGraph` as the minimal host machinery for the
first real evaluator graph. It orders descriptors so providers run before
consumers, treats unmatched requirements as host inputs, runs each evaluator
once for a projection pass, caches declared outputs by capability, and injects
cached outputs into downstream evaluator input.

The implementation deliberately stays below framework size: no registry,
plugin loading, versioning, sandboxing, persistence, Ash resources, migrations,
or UI. It only supports the mechanics needed by the concrete
`recent_load_metric -> marathon_adaptation` chain.

Added tests proving reversed descriptors are ordered deterministically, the
recent-load output is cached and passed into marathon adaptation, and the host
returns plain-English diagnostics for missing host inputs, missing evaluator
functions, omitted declared outputs, and invalid result shapes. Verification
passed with `mise run verify:backend`.
