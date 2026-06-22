---
# improve-ash-874v
title: Add same-plan validations for plan definitions
status: todo
type: feature
priority: high
created_at: 2026-06-22T21:38:29Z
updated_at: 2026-06-22T21:38:47Z
parent: improve-ash-dcal
blocked_by:
    - improve-ash-byh8
---

Ensure item types, items, pools, memberships, environments, event types, session templates, slots, direct goals, and schedules cannot reference records from another plan. Acceptance: negative tests cover mixed-plan definition writes.
