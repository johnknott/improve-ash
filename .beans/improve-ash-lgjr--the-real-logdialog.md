---
# improve-ash-lgjr
title: The real LogDialog
status: todo
type: feature
created_at: 2026-07-04T22:57:28Z
updated_at: 2026-07-04T22:57:28Z
parent: improve-ash-qyd7
blocked_by:
    - improve-ash-u6fx
---

Replace the stub: event type Select from planDetail.eventTypes → dynamic form from payload_schema ({required: [...], optional: [...]} — quantity/unit first-class, generic string/number fields after), item links by role from item_link_roles (required roles get item pickers filtered by item_type_key), note, effective date defaulting to selectedDate. Uses log-event (or log-linked-event when a role links an item). Built on the Phase 0 form kit.
