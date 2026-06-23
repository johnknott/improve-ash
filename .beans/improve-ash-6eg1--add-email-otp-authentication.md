---
# improve-ash-6eg1
title: Add email OTP authentication
status: completed
type: feature
created_at: 2026-06-23T11:05:49Z
updated_at: 2026-06-23T11:05:49Z
parent: improve-ash-qdoa
---

Implement the first auth slice from notes/auth-notes.md using AshAuthentication OTP.

- [x] Upgrade/add AshAuthentication at latest RC and inspect installed docs/source for OTP DSL.
- [x] Add token storage, OTP configuration, sender boundary, and migrations.
- [x] Add backend auth service/story tests for request and verify code.
- [x] Add Phoenix JSON endpoints for request-code, verify-code, me, and logout.
- [x] Add a simple Svelte email/code login flow and current-user state.
- [x] Verify with auth tests, frontend checks, and mise run verify.
