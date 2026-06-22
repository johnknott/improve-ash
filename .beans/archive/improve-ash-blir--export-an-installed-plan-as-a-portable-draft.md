---
# improve-ash-blir
title: Export an installed plan as a portable draft
status: completed
type: feature
priority: normal
created_at: 2026-06-22T21:38:29Z
updated_at: 2026-06-22T22:34:21Z
parent: improve-ash-r7aj
blocked_by:
    - improve-ash-4cpg
---

Add headless export from persisted plan data to stable-key draft JSON. Acceptance: gym and vial demo plans export without internal IDs and can be compared in deterministic tests.



Completed:
- Added Improve.Planning.PlanDraftExporter for authorized persisted-plan export to stable-key drafts.
- Added Plans.export_plan_draft/2 and export_plan_draft!/2 headless entry points.
- Export converts internal IDs to item_type_key, item_keys, available_item_keys, environment_key, pool_key, owner_key, and event_type_key.
- Export output is sorted deterministically and omits UUID-shaped internal IDs.
- Added gym and vial demo export tests, including diagnostics validation.
- mise run verify passes.
