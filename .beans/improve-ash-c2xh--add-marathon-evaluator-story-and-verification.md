---
# improve-ash-c2xh
title: Add marathon evaluator story and verification
status: completed
type: task
priority: normal
created_at: 2026-06-24T20:38:56Z
updated_at: 2026-06-25T03:55:00Z
parent: improve-ash-97ij
blocked_by:
    - improve-ash-o1ro
---

Add executable stories and tests proving the adaptive marathon plan through the internal evaluator contract.

The story should show structure, customization, derived adaptation, committed edit proposals, diagnostics, and review language.

Done when the forcing example either validates the contract or produces clear reasons to adjust it.

## Checklist

[x] Add a small pipeline that runs the concrete evaluator graph with the real
recent-load producer and marathon adaptation consumer.
[x] Add story helpers that assemble bounded marathon evaluator input from plan,
projection, journal, time-off, tracks, and explicit life-event examples.
[x] Update `10_adaptive_marathon.exs` so Layer 3 runs through the evaluator
contract instead of remaining purely commented.
[x] Add story/helper tests for derived adaptation and committed proposal output.
[x] Run backend verification.

## Summary of Changes

Added `Improve.Planning.Adaptation.MarathonPipeline`, which runs the concrete
internal evaluator graph with the real recent-load producer before the marathon
adaptation consumer.

Added story helpers that assemble bounded evaluator input from the plan,
projection, tracks, journal, time-off windows, and explicit life-event examples,
then print evaluator order, recent load, today's adapted work, derived
proposals, and committed proposals.

Updated `priv/scripts/stories/10_adaptive_marathon.exs` so Layer 3 now runs
through the evaluator contract for missed quality work, illness, injury, and
holiday re-entry. The story now shows declarative structure, baseline
customization, derived adaptation, committed proposal language, and diagnostics
from the evaluator graph.

Added story/helper regression coverage. Verification passed with
`mise run verify:backend`.
