---
# improve-ash-7on2
title: Generalize stateful item effects, correction, and offline stories
status: todo
type: epic
priority: normal
tags:
    - backend
    - journal
created_at: 2026-06-24T12:16:20Z
updated_at: 2026-06-24T12:16:20Z
parent: improve-ash-qdoa
---

## Context

Stateful items should prove starting facts, effects, derived state, warnings, correction, and offline ingress using generic product language. Domain-specific fixture content is fine, but the core API should not speak in vial/dose terms.

## Acceptance

- [ ] Stateful item stories use generic item/container/effect language.
- [ ] Effects are recorded through generic event/item links and interpreted by pure planning modules.
- [ ] Correction preserves auditable journal history.
- [ ] Offline duplicate/stale flows use product-facing diagnostics.
