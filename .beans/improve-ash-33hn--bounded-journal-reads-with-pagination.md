---
# improve-ash-33hn
title: Bounded journal reads with pagination
status: completed
type: task
priority: normal
created_at: 2026-07-04T13:20:04Z
updated_at: 2026-07-04T21:29:36Z
parent: improve-ash-fd57
---

read_journal loads every event and callers slice in memory; projection_load pulls all history. Add limits/keyset pagination at the query layer. (notes/fable-todo.md item #13)
