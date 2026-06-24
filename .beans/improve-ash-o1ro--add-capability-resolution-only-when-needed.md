---
# improve-ash-o1ro
title: Add capability resolution only when needed
status: draft
type: epic
priority: normal
created_at: 2026-06-24T20:37:34Z
updated_at: 2026-06-24T20:37:41Z
parent: improve-ash-zkg7
---

Introduce capability descriptors, evaluator dependencies, ordering, and caching only when a real second-order evaluator dependency exists.

The goal is to avoid speculative graph machinery while preserving the architecture needed for adaptation and derived metrics later.
