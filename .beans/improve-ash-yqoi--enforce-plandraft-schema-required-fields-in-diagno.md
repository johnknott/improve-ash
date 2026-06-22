---
# improve-ash-yqoi
title: Enforce PlanDraft schema required fields in diagnostics
status: completed
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
- [x] Run full verification.

Summary:
- `Diagnostics.validate_plan_draft/1` now enforces required fields from `PlanDraft.schema/0` for top-level fields, collection entries, and nested session slots.
- Added focused coverage for missing schema fields and updated the minimal supported draft fixture to include all required fields.
- Verification: `mise run verify` passed with 89 tests and TypeScript checking.
