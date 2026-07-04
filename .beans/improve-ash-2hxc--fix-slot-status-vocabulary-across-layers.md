---
# improve-ash-2hxc
title: Fix slot-status vocabulary across layers
status: completed
type: bug
priority: normal
created_at: 2026-07-04T13:20:04Z
updated_at: 2026-07-04T13:33:11Z
parent: improve-ash-fd57
---

slot_logged? only counts :completed/:skipped so swapped/partially_completed slots leave sessions un-completable; ProjectedWork declares :partially_completed while projector emits :partial. Reconcile the enum. (notes/fable-todo.md item #9)

## Summary of Changes

The audit claim was partially wrong: a swapped slot that carries a logged
event sets `event_instance_id`, which `slot_logged?` already counts — so
swap-then-log sessions could complete all along. Added a regression test
proving it (`test/improve/sessions_journal_test.exs`, "projection of swapped
slots").

The real defect was a dead status value. `:partially_completed` was declared
in the SlotResult constraint, the SessionOccurrence constraint and its three
transition guards, the offline freshness check, and ProjectedWork's status
list — but no action ever sets it, and the projector derives partial-ness
dynamically as `:partial`. Removed `:partially_completed` from all layers and
regenerated the TypeScript contracts (the value also leaked into
`ash_types.ts`). If a stored partial status is ever needed, that's a
deliberate future design decision, not a leftover enum value.
