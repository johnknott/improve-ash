---
# improve-ash-tun1
title: Build draft preview and counts
status: completed
type: feature
priority: normal
created_at: 2026-06-22T21:38:29Z
updated_at: 2026-06-22T22:43:13Z
parent: improve-ash-r7aj
blocked_by:
    - improve-ash-4cpg
---

Produce a headless preview for plan drafts with validity, diagnostics, plan summary, date range, and counts/lists for major objects. Acceptance: preview supports future Plan Store UI without depending on UI code.



Completed:
- Added Improve.Planning.PlanDraftPreview for pure headless draft previews.
- Added Plans.preview_plan_draft/1 helper.
- Preview returns validity, diagnostics, plan summary, date range, counts for major objects, and readable lists for sessions, goals, items, and event types.
- Added valid exported-gym preview and invalid-draft preview tests.
- mise run verify passes.
