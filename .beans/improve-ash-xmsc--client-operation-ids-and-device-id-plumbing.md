---
# improve-ash-xmsc
title: Client operation IDs and device ID plumbing
status: completed
type: task
priority: normal
created_at: 2026-07-04T22:57:28Z
updated_at: 2026-07-04T23:38:24Z
parent: improve-ash-qyd7
---

Stable client_device_id in localStorage (crypto.randomUUID once); a fresh client_operation_id generated per write submission and attached to log/session mutation bodies. One helper module; call sites stay clean. Proves the exact contract mobile will use.

## Summary of Changes
api/idempotency.ts: stable client_device_id in localStorage (crypto.randomUUID once), fresh client_operation_id per submission via operationIdempotency(). Attached in improveClient write functions (logTrack/logEvent/logSessionSlot). Retries dedupe server-side — proven by the log-track and log-session-slot idempotency controller tests.
