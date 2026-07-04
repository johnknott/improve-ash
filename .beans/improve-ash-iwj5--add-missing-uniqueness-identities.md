---
# improve-ash-iwj5
title: Add missing uniqueness identities
status: todo
type: task
created_at: 2026-07-04T13:20:04Z
updated_at: 2026-07-04T13:20:04Z
parent: improve-ash-fd57
---

SessionOccurrence unique on (plan_id, session_template_id, planned_for); identity for Schedule; decide on_delete for User.destroy path. (notes/fable-todo.md item #11)
