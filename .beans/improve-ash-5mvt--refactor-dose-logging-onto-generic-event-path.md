---
# improve-ash-5mvt
title: Refactor dose logging onto generic event path
status: completed
type: task
priority: high
created_at: 2026-06-22T21:37:54Z
updated_at: 2026-06-22T22:08:43Z
parent: improve-ash-u392
blocked_by:
    - improve-ash-jrrn
---

Make the vial dose scenario use the generic event/effect pathway while keeping the public spike scenario intact. Acceptance: dose log and correction tests still pass and no vial-specific effect creation remains in the orchestration layer except fixture convenience code.



Completed:
- Routed log_dose_event!/2 through the generic LogEventCommand path while preserving the public spike return shape.
- Routed the replacement event/effect side of correct_dose_event!/2 through the same generic persister.
- Added replaces_item_effect_id to LogEventCommand so generic effect creation preserves correction lineage.
- Focused journal/ownership tests pass and mise run verify passes.
