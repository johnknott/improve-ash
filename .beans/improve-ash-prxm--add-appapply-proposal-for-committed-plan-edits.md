---
# improve-ash-prxm
title: Add App.apply_proposal! for committed plan edits
status: completed
type: feature
priority: high
created_at: 2026-06-25T09:55:48Z
updated_at: 2026-06-25T10:53:27Z
parent: improve-ash-qz52
blocked_by:
    - improve-ash-2q7k
---

Add an app-facing orchestration entry point that accepts a plan, actor, and approval-required proposal. Dispatch extend_plan through the new Plan action, and return a clear unsupported-proposal diagnostic for actions such as adjust_goal until product design defines them. No projection-time side effects.

- Summary of Changes: Implemented Improve.App.Proposal with App.apply_proposal/3 and App.apply_proposal!/3. It accepts committed proposal maps, dispatches extend_plan through the core Plan action, returns explicit unsupported-action diagnostics for adjust_goal/unknown edits, avoids projection-time side effects, and is covered by App tests plus the review story. Full `mise run verify` is green.
