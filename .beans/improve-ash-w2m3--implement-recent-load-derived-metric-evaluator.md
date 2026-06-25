---
# improve-ash-w2m3
title: Implement recent-load derived metric evaluator
status: completed
type: task
created_at: 2026-06-24T23:47:08Z
updated_at: 2026-06-25T02:30:00Z
parent: improve-ash-97ij
---

Build the real hermetic recent_load_km evaluator for the adaptive marathon plan. It should read bounded projection input, compute running km in the 7 days ending at as_of_date, return plain-English diagnostics, and integrate with the existing evaluator graph tests without database, clock, network, AI, or journal mutation.

## Checklist

[x] Add a pure recent-load derived metric evaluator under `Improve.Planning`.
[x] Compute active linked run km inside the 7-day window ending on `as_of_date`.
[x] Return metric output plus plain-English diagnostics for ignored events and
empty history.
[x] Prove the evaluator through unit tests and the existing graph runner.
[x] Run backend verification.

## Summary of Changes

Added `Improve.Planning.DerivedMetrics.RecentLoad`, a hermetic evaluator that
computes `recent_load_km` from bounded projection input. It totals active
journal events linked to km-based running tracks inside the 7-day inclusive
window ending on `as_of_date`, returns event ids, window metadata, and
plain-English diagnostics for malformed run events or empty history.

Added focused tests for window boundaries, active/linked event filtering,
ignored-event diagnostics, and integration through `Improve.Planning.EvaluatorGraph`.
The graph now has a real `recent_load_metric` producer in tests instead of only
stubbed evaluator functions.

Verification passed with `mise run verify:backend`.
