---
# improve-ash-p2fg
title: Review Ash domain modelling philosophy
status: completed
type: task
priority: normal
created_at: 2026-06-23T14:00:30Z
updated_at: 2026-06-23T14:02:47Z
---

Assess whether improve-ash is using Ash as the business-domain engine or as a thin database wrapper.\n\n- [x] Inspect resource DSL, domains, policies, validations, calculations, aggregates, actions, and code interfaces\n- [x] Inspect orchestration and pure planning modules for rules that might belong in Ash\n- [x] Inspect tests and frontend/API surfaces for product-shaped usage\n- [x] Summarize verdict, aligned parts, concerns, and practical refactor priorities

## Summary of Changes\n\nReviewed the Ash resource graph, domains, policies, validations, imperative orchestration modules, pure planning modules, app facade, RPC/controller layer, and migrations. The final answer summarizes aligned areas, concerns, priority refactors, and concrete code examples.
