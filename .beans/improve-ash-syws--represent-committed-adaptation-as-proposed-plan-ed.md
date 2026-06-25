---
# improve-ash-syws
title: Represent committed adaptation as proposed plan edits
status: completed
type: task
priority: normal
created_at: 2026-06-24T20:38:56Z
updated_at: 2026-06-25T03:30:00Z
parent: improve-ash-97ij
blocked_by:
    - improve-ash-o1ro
---

Model adaptation that requires durable plan changes as explicit proposed edits, not projection side effects.

Examples include extending a plan, changing future phase structure, or replacing a schedule after injury.

Done when derived adaptation and user-approved committed changes are visibly separate in code and stories.

## Checklist

[x] Add a pure committed-proposal module for approval-required plan edits.
[x] Keep derived adaptation proposals separate from committed plan-edit
proposals in the marathon evaluator output.
[x] Cover illness, injury, and holiday/re-entry committed proposal cases.
[x] Ensure no plan structure is mutated by projection-time proposal generation.
[x] Run backend verification.

## Summary of Changes

Added `Improve.Planning.Adaptation.CommittedPlanEdits`, a pure proposal module
for approval-required plan edits. It describes committed adaptations such as
extending the plan after illness or injury, extending around a movable-deadline
time-off gap, or proposing a goal adjustment when the race date is fixed.

Updated the marathon adaptation evaluator to keep projection-time derived
proposals and committed plan-edit proposals visibly separate:

- `proposals`: no-write derived adaptation, always `requires_approval: false`.
- `committed_proposals`: approval-required proposed edits, always
  `effect: :committed`.

No plan structure is mutated during proposal generation. Acceptance and
persistence remain future core actions. Tests cover illness, injury, movable
holiday extension, fixed-deadline goal adjustment, and the separation between
derived and committed output.

Verification passed with `mise run verify:backend`.
