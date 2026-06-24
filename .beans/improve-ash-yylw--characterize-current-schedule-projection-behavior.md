---
# improve-ash-yylw
title: Characterize current schedule projection behavior
status: completed
type: task
priority: high
created_at: 2026-06-24T20:38:06Z
updated_at: 2026-06-24T20:41:35Z
parent: improve-ash-8qr7
---

Add or tighten tests around the current schedule projection behavior before extracting evaluators.

Cover implemented schedule kinds, recognized-but-unsupported schedules, unknown schedule shapes, and existing plain-English diagnostics.

Done when the expected behavior is pinned down enough that the evaluator extraction can be refactored safely.

## Summary of Changes

Added projector characterization coverage for selected-weekday schedules, malformed every-N-days rules, and unknown schedule kinds. Confirmed the focused projector test file passes with `mix test test/improve/planning/project_today_test.exs`.
