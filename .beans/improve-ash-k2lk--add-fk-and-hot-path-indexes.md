---
# improve-ash-k2lk
title: Add FK and hot-path indexes
status: todo
type: task
created_at: 2026-07-04T13:20:04Z
updated_at: 2026-07-04T13:20:04Z
parent: improve-ash-fd57
---

No non-unique index exists. Add event_instances(plan_id, effective_at), item_effects(event_instance_id), event_item_links(event_instance_id, item_id), slot_results(session_occurrence_id), and other FK indexes. (notes/fable-todo.md item #10)
