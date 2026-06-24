---
# improve-ash-4ib0
title: Let simple tracks imply simple event types
status: completed
type: task
priority: normal
tags:
    - backend
    - story-api
created_at: 2026-06-24T12:15:33Z
updated_at: 2026-06-24T12:34:28Z
parent: improve-ash-vl5b
blocked_by:
    - improve-ash-hy0v
---

## Context

Users should not start a plain track by defining event types. The app can infer simple journal records from the track target/records declaration.

## Tasks

- [x] Teach `App.add_track!` how to create or connect a simple event type from `records:` metadata.
- [x] Support fixed amount, metric recording, and checklist-style event payloads where practical.
- [x] Keep advanced direct event-type authoring available for templates.
- [x] Add tests proving the implied event type is used by `log_track!`.

## Acceptance

- [x] The reading story can create and log a simple track without manually defining an event schema.

## Summary of Changes

Made `event:` optional for simple `App.add_track!` calls. Tracks with `records:` now create or reuse an inferred event type with a stable key and payload schema, while explicit event type authoring still works for advanced templates. Updated the reading story and tests to prove `log_track!` uses the inferred event type. Verified with `mise run test`, the reading story under `MIX_ENV=test`, AshTypescript codegen check, TypeScript check, and old-vocabulary search.
