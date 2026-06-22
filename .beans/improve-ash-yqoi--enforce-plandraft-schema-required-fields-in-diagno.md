---
# improve-ash-yqoi
title: Enforce PlanDraft schema required fields in diagnostics
status: in-progress
type: feature
priority: high
created_at: 2026-06-22T23:18:00Z
updated_at: 2026-06-22T23:18:00Z
parent: improve-ash-fx46
---

Diagnostics.validate_plan_draft/1 should enforce PlanDraft.schema/0 required top-level, collection, and child fields so preview/import report schema problems before Ash persistence.

Todo:
- [x] Add schema-driven required-field diagnostics for top-level draft fields.
- [x] Add schema-driven required-field diagnostics for collection entries and child slots.
- [x] Update focused diagnostics tests for stricter schema-minimal drafts.
- [ ] Run full verification.
