---
# improve-ash-ooye
title: Make correction and offline stories product-facing
status: todo
type: task
priority: normal
tags:
    - backend
    - journal
created_at: 2026-06-24T12:16:37Z
updated_at: 2026-06-24T12:17:50Z
parent: improve-ash-7on2
blocked_by:
    - improve-ash-9d40
---

## Context

Correction and offline ingress are important backend workflows, but their stories should describe user-facing behavior rather than internal IDs and payload plumbing.

## Tasks

- [ ] Rewrite correction story output around original event, corrected event, replacement event, and active effects.
- [ ] Rewrite offline story output around accepted, duplicate, stale, and retried entries.
- [ ] Keep transactions explicit in backend workflows.
- [ ] Add/adjust tests for correction history and duplicate/stale diagnostics.

## Acceptance

- [ ] Correction and offline stories can be read as product behavior while still proving the journal internals.
