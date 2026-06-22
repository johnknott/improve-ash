---
# improve-ash-mzku
title: Expand authored-content diagnostics
status: completed
type: task
priority: normal
created_at: 2026-06-22T21:38:29Z
updated_at: 2026-06-22T22:41:30Z
parent: improve-ash-r7aj
blocked_by:
    - improve-ash-4cpg
---

Extend diagnostics to catch event link role mistakes, effect rules pointing at missing roles, target/unit mismatches, duplicate keys, and schedule shapes that cannot be projected. Acceptance: plain-English diagnostics have focused tests.



Completed:
- Expanded Diagnostics.validate_plan_draft/1 to catch stable-key reference errors across items, pools, environments, direct goals, schedules, and sample events.
- Added diagnostics for duplicate event item-link roles, direct goal quantity/unit target mismatches, unsupported schedule owner types, and unsupported times_per_week rule shapes.
- Updated importer to reuse the shared draft diagnostics and only add import-specific date requirements.
- Added focused diagnostics tests and updated the minimal supported draft test to the current schedule owner shape.
- mise run verify passes.
