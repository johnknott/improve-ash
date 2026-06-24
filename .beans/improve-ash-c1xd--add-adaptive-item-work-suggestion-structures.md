---
# improve-ash-c1xd
title: Add adaptive item-work suggestion structures
status: done
type: task
priority: normal
tags:
    - backend
    - adaptive
created_at: 2026-06-24T12:16:06Z
updated_at: 2026-06-24T12:50:41Z
parent: improve-ash-xqim
blocked_by:
    - improve-ash-fzzv
---

## Context

Adaptive targets need a generic way to suggest work for an item from cold start, history, coach review, or manual rules. This should not hard-code exercise fields.

## Tasks

- [x] Add projection structures for suggested payload, suggestion reason, suggestion source, and previous relevant events.
- [x] Support adaptive target metadata such as fields, effort field, and review cadence.
- [x] Keep recommendation logic deterministic and input-driven.
- [x] Add tests for cold-start and history-based suggestions.

## Acceptance

- [x] A session slot can suggest generic field values for an item and preserve the actual values logged by the user.
