---
# improve-ash-zhka
title: Add generic stateful item and effect authoring helpers
status: todo
type: task
priority: normal
tags:
    - backend
    - journal
created_at: 2026-06-24T12:16:26Z
updated_at: 2026-06-24T12:16:26Z
parent: improve-ash-7on2
---

## Context

The core should model stateful items generically: starting facts plus active effects.

## Tasks

- [ ] Ensure `App.add_item_type!` supports friendly fact declarations.
- [ ] Ensure `App.add_item!` can declare stateful items with starting facts.
- [ ] Add or refine generic effect constructors: subtract quantity, add quantity, set quantity.
- [ ] Keep effect interpretation in pure planning modules.
- [ ] Add tests for starting facts plus active effects.

## Acceptance

- [ ] A story can define a generic container, log use from it, and derive current quantity.
