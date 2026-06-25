---
# improve-ash-b8ju
title: Add Phoenix app-controller negative tests
status: todo
type: task
priority: normal
created_at: 2026-06-25T09:56:05Z
updated_at: 2026-06-25T09:56:10Z
parent: improve-ash-6lsw
---

Add negative request coverage for unauthenticated app API calls, cross-user plan/resource IDs, and malformed payloads. The goal is not new behavior; it is proving thin controller delegation and policy/error handling stay trustworthy.
