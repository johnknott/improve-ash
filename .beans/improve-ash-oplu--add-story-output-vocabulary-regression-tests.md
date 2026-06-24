---
# improve-ash-oplu
title: Add story-output vocabulary regression tests
status: todo
type: task
priority: normal
tags:
    - backend
    - tests
created_at: 2026-06-24T12:16:59Z
updated_at: 2026-06-24T12:17:57Z
parent: improve-ash-qtdm
blocked_by:
    - improve-ash-gbxn
---

## Context

The backend story layer is a product-language testbed. Tests should catch awkward internal vocabulary before UI work starts depending on it.

## Tasks

- [ ] Add tests or assertions for story output vocabulary.
- [ ] Reject `direct_goal` in product-facing stories and output.
- [ ] Keep raw payload/effect/link terminology out of simple happy-path story output.
- [ ] Allow internal/debug output to show low-level details deliberately.

## Acceptance

- [ ] Product-facing story output fails tests if it regresses into internal terms.
