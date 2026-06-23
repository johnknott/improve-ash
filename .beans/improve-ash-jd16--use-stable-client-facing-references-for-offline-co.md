---
# improve-ash-jd16
title: Use stable client-facing references for offline commands
status: todo
type: task
priority: deferred
created_at: 2026-06-23T09:58:39Z
updated_at: 2026-06-23T09:58:39Z
parent: improve-ash-qdoa
---

Deferred until mobile/offline UI work. Offline command payloads should move away from raw server IDs where possible and support stable app-facing references.\n\nCandidate references:\n- [ ] plan key or client plan ref\n- [ ] direct goal key\n- [ ] session occurrence client ref\n- [ ] slot client ref\n- [ ] item key\n- [ ] event type key\n- [ ] idempotency key and client event id\n\nKeep current raw-ID support while adding this so existing story coverage remains useful.
