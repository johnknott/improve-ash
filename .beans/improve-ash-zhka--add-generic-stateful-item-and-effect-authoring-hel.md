---
# improve-ash-zhka
title: Add generic stateful item and effect authoring helpers
status: done
type: task
priority: normal
tags:
    - backend
    - journal
created_at: 2026-06-24T12:16:26Z
updated_at: 2026-06-24T12:59:20Z
parent: improve-ash-7on2
---

## Context

The core should model stateful items generically: starting facts plus active effects.

## Tasks

- [x] Ensure `App.add_item_type!` supports friendly fact declarations.
- [x] Ensure `App.add_item!` can declare stateful items with starting facts.
- [x] Add or refine generic effect constructors: subtract quantity, add quantity, set quantity.
- [x] Keep effect interpretation in pure planning modules.
- [x] Add tests for starting facts plus active effects.

## Acceptance

- [x] A story can define a generic container, log use from it, and derive current quantity.
