---
# improve-ash-42ig
title: Fix summary and correction/path correctness gaps
status: completed
type: task
priority: high
created_at: 2026-06-22T23:18:00Z
updated_at: 2026-06-22T23:21:30Z
parent: improve-ash-fx46
---

First pass over review feedback. Todo:\n- [x] Count direct goals in Plans.summarize_plan/2 and AI summary output.\n- [x] Share nested payload path reading between diagnostics and EffectRuleInterpreter.\n- [x] Ensure correct_generic_event only voids effects from the original event.\n- [x] Add focused tests and run verification.

\n\n## Summary of Changes\n\n- Added direct goal counts to plan summaries, which also fixes the AI get_plan_summary tool output.\n- Added Improve.Planning.PathReader and reused it from diagnostics and EffectRuleInterpreter so nested payload paths agree at preview/runtime.\n- Added correction diagnostics so original effects must belong to the original event before any void/replacement work runs.\n- Verification: mise run verify passes with 85 tests.
