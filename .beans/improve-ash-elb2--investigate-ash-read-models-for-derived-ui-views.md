---
# improve-ash-elb2
title: Investigate Ash read models for derived UI views
status: draft
type: task
priority: deferred
created_at: 2026-06-25T12:12:38Z
updated_at: 2026-06-25T12:12:38Z
---

Later, once the UI page shapes are more stable, investigate whether composed derived views such as Today, Plan, Journal, or Dashboard would be cleaner as Ash read-model resources exposed through AshTypescript RPC, or as database views/materialized read models, instead of only hand-shaped Phoenix endpoints.\n\nContext:\n- Today-style pages are derived views, not durable domain entities.\n- The current pragmatic shape is Phoenix page endpoints that call Ash reads/actions plus plain Elixir projection modules.\n- Ash can theoretically model derived/read-only view resources, and AshTypescript can expose read actions over RPC.\n- Database views or materialized read models may also be worth considering if the shape stabilizes and query efficiency becomes important.\n\nQuestions to answer later:\n- Would an Ash read-model resource make authorization, contracts, loads, and TypeScript calls cleaner?\n- Would it bend the domain model around UI screens too much?\n- Would a Postgres view/materialized view simplify or speed up the read path?\n- Which views are stable enough to deserve a named backend read model?\n\nDone when:\n- We compare plain Phoenix page endpoints, Ash read-model resources, and DB view/materialized read models against at least one real UI page.\n- We document a recommendation and, if useful, create implementation beans for the chosen approach.
