---
# improve-ash-hww5
title: Generalize event correction and effect replacement
status: completed
type: feature
priority: normal
created_at: 2026-06-22T21:37:54Z
updated_at: 2026-06-22T22:13:39Z
parent: improve-ash-u392
blocked_by:
    - improve-ash-jrrn
---

Turn dose correction into a generic correction workflow for events with generated effects. Acceptance: correcting an event voids/replaces affected links/effects consistently, preserves audit history, and works for at least one non-vial effect example.



Completed:
- Added correct_generic_event/2 and correct_generic_event!/2 for generic event correction.
- Generic correction marks the original event corrected, voids supplied original effects, annotates replacement links, and persists the replacement event through LogEventCommand.
- Generic replacement effects now preserve replaces_item_effect_id by matching original effects.
- Refactored correct_dose_event!/2 into a thin compatibility wrapper around generic correction.
- Added non-vial reading-progress correction coverage.
- Focused tests pass and mise run verify passes.
