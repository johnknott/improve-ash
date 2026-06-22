---
# improve-ash-jgjg
title: Route legacy session item logging through generic event path
status: todo
type: task
priority: normal
created_at: 2026-06-22T23:18:00Z
updated_at: 2026-06-22T23:18:00Z
parent: improve-ash-fx46
---

Reimplement log_session_item_event!/2 via log_generic_event!/2 where practical so session exercise logs use the same idempotency, effect-rule, validation, and slot-update machinery as other event writes.
