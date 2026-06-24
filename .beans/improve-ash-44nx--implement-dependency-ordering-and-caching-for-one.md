---
# improve-ash-44nx
title: Implement dependency ordering and caching for one real graph
status: draft
type: task
priority: normal
created_at: 2026-06-24T20:38:44Z
updated_at: 2026-06-24T20:38:44Z
parent: improve-ash-o1ro
blocked_by:
    - improve-ash-z91i
---

Once a real evaluator dependency exists, add only enough host machinery to order evaluators and cache outputs for that graph.

Avoid building a general-purpose rules engine.

Done when one concrete dependency chain runs deterministically with tests.
