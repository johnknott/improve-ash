---
# improve-ash-fian
title: Idempotent event logging over HTTP
status: completed
type: feature
priority: normal
created_at: 2026-07-04T13:20:04Z
updated_at: 2026-07-04T19:11:09Z
parent: improve-ash-fd57
---

Plumb client_operation_id/idempotency_key/client_device_id through /app/log-event, /app/log-linked-event, /app/log-session-slot. Machinery exists in Journal; only the API boundary is missing. (notes/fable-todo.md item #1)

## Summary of Changes

- `UiApi.idempotency_from_params/1` extracts `client_event_id`,
  `client_operation_id`, `client_device_id`, `idempotency_key` from request
  params (nil when absent, so unadorned requests behave as before).
- Wired into all three log paths: `log_attrs` (`/app/log-event`),
  `linked_event_attrs` (`/app/log-linked-event`), and
  `log_session_slot_event` → `App.log_session_slot!` opts
  (`/app/log-session-slot`).
- `Journal.linked_item_event_command_attrs` and the session-slot attrs in
  `App.Logging` now forward `:idempotency` into `LogEventCommand`, which
  already validated and deduped it (partial unique indexes + pre-check).
- Duplicate replays return the original event (including its slot_result),
  so retrying clients get an identical 200.
- Tests: `/app/log-event` replay returns the same event id with one journal
  row; partial metadata (device without op id/key) 422s with the command's
  diagnostic; the gym session flow test now replays its slot log and
  asserts `slot_results_logged` stays 1.
