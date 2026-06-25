---
# improve-ash-q6p8
title: Implement derived adaptation scenarios
status: completed
type: task
priority: normal
created_at: 2026-06-24T20:38:56Z
updated_at: 2026-06-25T03:05:00Z
parent: improve-ash-97ij
blocked_by:
    - improve-ash-o1ro
---

Add projection-time adaptation scenarios for missed sessions, illness, injury, holidays, or similar interruptions.

These adaptations should be derived during projection and should not rewrite journal history or mutate plan structure.

Done when today/future recommendations can adapt from history while remaining recomputable.

## Checklist

[x] Refine the adaptation capability descriptor to include bounded date and
recent-missed-work inputs.
[x] Add a pure marathon adaptation evaluator with no writes or hidden I/O.
[x] Cover missed quality, illness, injury, and holiday re-entry as derived
projection output.
[x] Keep committed plan edits out of this bean; they remain proposed separately
in `improve-ash-syws`.
[x] Run backend verification.

## Summary of Changes

Added `Improve.Planning.Adaptation.Marathon` as a pure projection-time
adaptation evaluator. It consumes the derived `recent_load_km` output rather
than recomputing load, applies no writes, and returns derived adaptation output
for the four forcing scenarios: missed quality work, first day back after fever,
active injury, and first run back after a fully-off holiday.

Refined the marathon adaptation descriptor with two bounded host inputs the
implementation needs in practice: `date` and `recent_missed_work`. This keeps
missed-session handling explicit instead of making the adaptation evaluator
recalculate schedules or take the whole projection world.

Added tests proving derived proposals are recomputable and approval-free, and
that the concrete graph can run the real recent-load producer before the real
marathon adaptation consumer. Committed plan edits remain out of this bean and
belong to `improve-ash-syws`.

Verification passed with `mise run verify:backend`.
