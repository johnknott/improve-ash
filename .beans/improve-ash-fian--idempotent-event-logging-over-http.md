---
# improve-ash-fian
title: Idempotent event logging over HTTP
status: todo
type: feature
created_at: 2026-07-04T13:20:04Z
updated_at: 2026-07-04T13:20:04Z
parent: improve-ash-fd57
---

Plumb client_operation_id/idempotency_key/client_device_id through /app/log-event, /app/log-linked-event, /app/log-session-slot. Machinery exists in Journal; only the API boundary is missing. (notes/fable-todo.md item #1)
