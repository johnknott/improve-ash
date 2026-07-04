---
# improve-ash-natd
title: Expose offline batch ingress over HTTP
status: completed
type: feature
priority: deferred
created_at: 2026-06-25T09:54:17Z
updated_at: 2026-07-04T19:14:41Z
parent: improve-ash-fd57
---

V1.1 follow-up, not a V1 backend blocker. App.submit_offline_events! and journal batch ingress are already implemented and tested; this bean tracks exposing that workflow through a Phoenix endpoint when the client has an offline outbox story.

## Summary of Changes

- New route `POST /api/app/offline-events` → `AppController.submit_offline_events`
  → `UiApi.submit_offline_events/2`.
- The boundary normalizes each JSON entry (string keys, ISO8601 datetimes,
  optional track/session/slot references, item links, idempotency metadata)
  into the atom-keyed command maps `Journal.submit_offline_event_batch/2`
  expects, forcing `origin: :offline_sync`.
- Response: per-entry results with `index`, `status`
  (accepted/duplicate/rejected/needs_resolution), `clientOperationId`,
  `idempotencyKey`, `eventInstanceId`, `conflictCategory`, and
  human-readable diagnostics — the outbox-clearing contract from
  notes/offline-journal-ingress.md.
- Controller test: a batch of [entry, same entry, entry with unknown event
  type] returns accepted/duplicate/needs_resolution(missing_plan_record),
  persists exactly one event, and an empty batch 422s.

This endpoint plus idempotent logging (improve-ash-fian) and bearer tokens
(improve-ash-9bkp, still open) forms the mobile backend contract.
