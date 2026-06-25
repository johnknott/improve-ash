---
# improve-ash-prxm
title: Add App.apply_proposal! for committed plan edits
status: todo
type: feature
priority: high
created_at: 2026-06-25T09:55:48Z
updated_at: 2026-06-25T09:55:55Z
parent: improve-ash-qz52
blocked_by:
    - improve-ash-2q7k
---

Add an app-facing orchestration entry point that accepts a plan, actor, and approval-required proposal. Dispatch extend_plan through the new Plan action, and return a clear unsupported-proposal diagnostic for actions such as adjust_goal until product design defines them. No projection-time side effects.
