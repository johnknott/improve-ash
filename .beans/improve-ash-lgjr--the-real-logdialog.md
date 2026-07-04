---
# improve-ash-lgjr
title: The real LogDialog
status: completed
type: feature
priority: normal
created_at: 2026-07-04T22:57:28Z
updated_at: 2026-07-04T23:38:24Z
parent: improve-ash-qyd7
blocked_by:
    - improve-ash-u6fx
---

Replace the stub: event type Select from planDetail.eventTypes → dynamic form from payload_schema ({required: [...], optional: [...]} — quantity/unit first-class, generic string/number fields after), item links by role from item_link_roles (required roles get item pickers filtered by item_type_key), note, effective date defaulting to selectedDate. Uses log-event (or log-linked-event when a role links an item). Built on the Phase 0 form kit.

## Summary of Changes
LogDialog rebuilt: event-type Select from planDetail.eventTypes → dynamic form from payload_schema (quantity/unit/amount first-class, other required/optional fields rendered), item-link roles from item_link_roles (required roles get item pickers filtered by item_type_key), note, effective date. Verified end-to-end logging a vial dose with source_vial link → derived subtract_quantity effect. Fixed a Svelte props_invalid_value runtime error: the form-kit inputs (TextInput/NumberInput/DateInput) declared $bindable('') fallbacks, so binding an initially-undefined object property (rendered before the seed effect ran) threw and wedged the dialog subtree. Removed the fallback defaults so bindable inputs tolerate undefined.
