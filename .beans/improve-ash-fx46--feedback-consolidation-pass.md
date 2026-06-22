---
# improve-ash-fx46
title: Feedback consolidation pass
status: completed
type: milestone
priority: high
created_at: 2026-06-22T23:17:43Z
updated_at: 2026-06-22T23:17:43Z
---

Work through the latest review feedback: fix plan summaries, harden correction ownership, share nested payload path reading, validate live event commands against authored event type contracts, strengthen plan draft schema diagnostics, route legacy session item logging through the generic command path where practical, and revisit today-aware quota behavior.

Summary:
- Completed the review consolidation pass across summary counts, nested path reading, generic correction safety, live event command validation, PlanDraft required-field diagnostics, session logging consolidation, and today-aware quota placement.
- Final verification: `mise run verify` passed with 91 tests and TypeScript checking.
