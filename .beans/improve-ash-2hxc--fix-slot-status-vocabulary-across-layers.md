---
# improve-ash-2hxc
title: Fix slot-status vocabulary across layers
status: todo
type: bug
created_at: 2026-07-04T13:20:04Z
updated_at: 2026-07-04T13:20:04Z
parent: improve-ash-fd57
---

slot_logged? only counts :completed/:skipped so swapped/partially_completed slots leave sessions un-completable; ProjectedWork declares :partially_completed while projector emits :partial. Reconcile the enum. (notes/fable-todo.md item #9)
