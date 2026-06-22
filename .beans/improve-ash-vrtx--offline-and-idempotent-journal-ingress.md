---
# improve-ash-vrtx
title: Offline and idempotent journal ingress
status: todo
type: epic
priority: normal
created_at: 2026-06-22T21:37:18Z
updated_at: 2026-06-22T21:37:18Z
parent: improve-ash-9pfh
---

Design and implement the modest offline logging foundation described in notes/full-rewrite-spec.md: client-generated IDs, idempotency keys, effective and recorded timestamps, pending-event batch acceptance, and clear per-command results.\n\nOut of scope: full local-first sync, conflict-free replicated data types, and offline plan editing.
