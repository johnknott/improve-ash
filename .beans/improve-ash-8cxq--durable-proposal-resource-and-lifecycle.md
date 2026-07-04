---
# improve-ash-8cxq
title: Durable Proposal resource and lifecycle
status: todo
type: feature
created_at: 2026-07-04T19:43:23Z
updated_at: 2026-07-04T19:43:23Z
parent: improve-ash-xxkf
---

Proposal resource: status proposed/approved/dismissed/applied/expired, source evaluator, proposed edit, evidence, affected fields. Upsert on consecutive-day divergence. App API: list pending, approve (idempotent apply), dismiss with reason; dismissals inform future evaluator runs. Applied proposals form an audit trail. (notes/coaching-foundations-todo.md item 3)
