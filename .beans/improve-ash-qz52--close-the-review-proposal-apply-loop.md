---
# improve-ash-qz52
title: Close the review proposal apply loop
status: completed
type: epic
priority: high
created_at: 2026-06-25T09:54:17Z
updated_at: 2026-06-25T10:52:51Z
parent: improve-ash-8e5j
---

Let the backend apply the concrete durable proposal shape we already produce. V1 only needs extend_plan to be actionable; unsupported proposal actions should return clear diagnostics rather than silently failing.

- Summary of Changes: The backend can now close the concrete committed proposal loop for extend_plan: review/story output can surface an approval-required proposal, App.apply_proposal dispatches it to the core Plan extend_plan action, unsupported proposal actions return explicit diagnostics, and the story demonstrates the approved edit. Full `mise run verify` is green.
