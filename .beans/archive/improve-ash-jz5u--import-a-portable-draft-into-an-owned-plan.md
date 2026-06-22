---
# improve-ash-jz5u
title: Import a portable draft into an owned plan
status: completed
type: feature
priority: normal
created_at: 2026-06-22T21:38:29Z
updated_at: 2026-06-22T22:38:31Z
parent: improve-ash-r7aj
blocked_by:
    - improve-ash-4cpg
---

Add transactional draft installation from stable-key JSON into owned plan records. Acceptance: import creates a user-owned editable copy and reports useful errors without partial installs.



Completed:
- Added Improve.Planning.PlanDraftImporter for diagnostic-first transactional draft import.
- Added Plans.import_plan_draft/2 and import_plan_draft!/2 headless entry points.
- Import creates user-owned draft-status plans with source_kind :imported and stable source_key.
- Import creates item types, items, pools, memberships, environments, event types, session templates, slots, direct goals, and schedules from stable keys.
- Added preflight reference diagnostics so invalid drafts fail before persistence and leave no partial plan.
- Import transaction collects and dispatches Ash notifications after commit.
- Added round-trip gym import, direct-goal import, and no-partial-install tests.
- mise run verify passes.
