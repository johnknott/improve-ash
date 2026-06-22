---
# improve-ash-vrtx
title: Offline and idempotent journal ingress
status: completed
type: epic
priority: normal
created_at: 2026-06-22T21:37:18Z
updated_at: 2026-06-22T22:57:14Z
parent: improve-ash-9pfh
---

Design and implement the modest offline logging foundation described in notes/full-rewrite-spec.md: client-generated IDs, idempotency keys, effective and recorded timestamps, pending-event batch acceptance, and clear per-command results.\n\nOut of scope: full local-first sync, conflict-free replicated data types, and offline plan editing.

\n\nCompleted: all child Beans are done. The offline foundation now has a design note, persisted idempotency metadata and uniqueness, duplicate-safe generic event retries, batch ingress with per-command results, and stale-reference handling for missing, cross-plan, archived, and changed session/slot references. Verification: latest mise run verify passes with 82 tests.
