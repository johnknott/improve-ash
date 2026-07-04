---
# improve-ash-oim8
title: Batch Lookup/SamePlan query patterns
status: todo
type: task
created_at: 2026-07-04T13:20:04Z
updated_at: 2026-07-04T13:20:04Z
parent: improve-ash-fd57
---

App.Lookup fetches entire collections per lookup; SamePlan fires an existence query per referenced field (5 per event log). Batch reference checks, add keyed fetches. (notes/fable-todo.md item #17)
