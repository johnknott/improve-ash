---
# improve-ash-9d40
title: Rewrite vial inventory story as generic stateful item story
status: todo
type: task
priority: normal
tags:
    - backend
    - stories
created_at: 2026-06-24T12:16:32Z
updated_at: 2026-06-24T12:17:48Z
parent: improve-ash-7on2
blocked_by:
    - improve-ash-zhka
---

## Context

The current vial workflow proves important item-state behavior, but the default story should use generic stateful-item language.

## Tasks

- [ ] Create or rewrite a story like `06_stateful_item_effects.exs`.
- [ ] Use item type, item, event, link, effect, derived state, warning, and correction vocabulary.
- [ ] Keep domain-specific vial demo data only in fixture/demo content where needed.
- [ ] Update story specs for derived quantity and correction behavior.

## Acceptance

- [ ] The story proves effects and current state without core `dose`/`vial` API calls.
