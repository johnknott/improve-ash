---
# improve-ash-fzzv
title: Preserve recommendation versus actual slot results
status: todo
type: task
priority: normal
tags:
    - backend
    - sessions
created_at: 2026-06-24T12:16:01Z
updated_at: 2026-06-24T12:17:37Z
parent: improve-ash-xqim
blocked_by:
    - improve-ash-t41l
---

## Context

The journal must preserve the difference between what the app suggested and what the user actually did.

## Tasks

- [ ] Ensure projected slot recommendations include recommended item, suggested payload, reason, source, and relevant history where available.
- [ ] Ensure slot results persist recommended item, actual item, suggested payload, actual payload, linked event, notes, and status.
- [ ] Update `start_session!` and `log_session_slot!` APIs to use product-language inputs.
- [ ] Add tests for swaps, skipped slots, and completed slots.

## Acceptance

- [ ] A session can recommend one item, log a different actual item, and show both in projection/history.
