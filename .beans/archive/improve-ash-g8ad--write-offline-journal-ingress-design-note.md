---
# improve-ash-g8ad
title: Write offline journal ingress design note
status: completed
type: task
priority: normal
created_at: 2026-06-22T21:38:29Z
updated_at: 2026-06-22T22:46:13Z
parent: improve-ash-vrtx
---

Capture the minimal offline logging protocol: client operation IDs, idempotency keys, device IDs, effective/recorded timestamps, batch results, server validation, and conflict categories. Acceptance: design note references notes/full-rewrite-spec.md and informs future API shape.

\n\nCompleted: added notes/offline-journal-ingress.md covering the minimal offline journal protocol, client operation IDs, idempotency keys, device IDs, timestamp semantics, batch results, server validation, and conflict categories. The note references notes/full-rewrite-spec.md and notes/spike-spec.md and outlines the follow-on API/schema work.
