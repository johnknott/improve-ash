---
# improve-ash-c4j1
title: Implement monthly schedule projection
status: todo
type: task
priority: high
created_at: 2026-06-25T09:54:58Z
updated_at: 2026-06-25T09:55:24Z
parent: improve-ash-aszg
---

Add a monthly schedule evaluator for the existing monthly vocabulary. It should project on the configured day of month, handle short months deliberately, emit plain-English diagnostics for malformed rules, and cover both track and session owners in tests.
