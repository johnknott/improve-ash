---
# improve-ash-mpff
title: Add same-plan validations for session and journal writes
status: todo
type: feature
priority: high
created_at: 2026-06-22T21:38:29Z
updated_at: 2026-06-22T21:38:47Z
parent: improve-ash-dcal
blocked_by:
    - improve-ash-byh8
---

Ensure session occurrences, slot results, events, event item links, and item effects cannot mix IDs across plans. Acceptance: negative tests prove cross-plan session/journal writes fail even when the actor owns both plans.
