---
# improve-ash-jd16
title: Use stable client-facing references for offline commands
status: completed
type: task
priority: deferred
created_at: 2026-06-23T09:58:39Z
updated_at: 2026-06-24T13:06:07Z
parent: improve-ash-qdoa
---

Offline command payloads should move away from raw server IDs where possible and support stable app-facing references.

Covered now:
- [x] track key
- [x] item key
- [x] event type key
- [x] idempotency key and client event id

Future mobile/offline-client work:
- [ ] plan key or client plan ref
- [ ] session occurrence client ref
- [ ] slot client ref

Raw-ID support remains available for session occurrence and slot result references while the client reference model is still being designed.
