---
# improve-ash-4cpg
title: Define versioned plan draft schema with stable keys
status: completed
type: task
priority: normal
created_at: 2026-06-22T21:38:29Z
updated_at: 2026-06-22T22:30:32Z
parent: improve-ash-r7aj
---

Define the portable authored plan shape for bundles/drafts using stable keys instead of database IDs. Acceptance: schema covers items, item types, pools, environments, event types, session templates, direct goals, schedules, targets, and policies at a first useful depth.



Completed:
- Added Improve.Planning.PlanDraft as the versioned portable draft schema source.
- Schema covers item types, items, pools, environments, event types, session templates, direct goals, schedules, sample events, targets, completion policies, and missed-work policies at a first useful depth.
- Draft references use stable keys instead of database IDs.
- Added notes/plan-draft-schema.md.
- Expanded keyed draft diagnostics to include direct_goals, schedules, and sample_events.
- Added focused schema and diagnostics integration tests.
- mise run verify passes.
