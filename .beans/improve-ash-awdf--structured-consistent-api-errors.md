---
# improve-ash-awdf
title: Structured, consistent API errors
status: completed
type: feature
priority: normal
created_at: 2026-07-04T13:20:04Z
updated_at: 2026-07-04T19:23:08Z
parent: improve-ash-fd57
---

One error envelope across AppController/AuthController/ErrorJSON, field-level validation errors instead of space-joined strings, stop rescuing all exceptions into 422s. (notes/fable-todo.md item #7)

## Summary of Changes

- New `ImproveWeb.ApiError`: every error renders as
  `{"error": {"code", "message", "details": [{"field", "message"}]}}`.
  Codes: `unauthenticated`, `invalid_credentials`, `not_found`,
  `validation_failed`, `rate_limited`, `invalid_request`, `request_failed`,
  `internal_error`.
- `AppController`, `AuthController`, `DevMailboxController`, and
  `ErrorJSON` (framework 404/500) all emit the envelope — the old
  `errors/detail` vs `error/message` split is gone.
- Plan and track validation diagnostics in `UiApi` are now
  `%{field, message}` maps, so clients get field-level errors;
  `message` remains the joined human-readable summary (existing message
  assertions unchanged). String diagnostics from deeper layers surface as
  details with `field: null`.
- The rescue-narrowing half was already done in improve-ash-svdo.
- Tests: malformed plan payload asserts code + all three field details;
  ErrorJSON tests assert the envelope.
