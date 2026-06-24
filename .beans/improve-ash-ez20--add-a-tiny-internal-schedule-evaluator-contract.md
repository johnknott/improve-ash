---
# improve-ash-ez20
title: Add a tiny internal schedule evaluator contract
status: completed
type: task
priority: high
created_at: 2026-06-24T20:38:06Z
updated_at: 2026-06-24T20:44:25Z
parent: improve-ash-8qr7
---

Introduce the smallest internal contract needed for schedule projection evaluators.

Keep it under planning/internal naming, use concrete inputs/results where practical, and avoid marketplace/plugin language.

Done when one existing schedule kind can be evaluated through the contract without changing projection output.

## Summary of Changes

Added a small internal schedule evaluator contract under `Improve.Planning.Schedules`: an `Evaluation` struct, an `Evaluator` behaviour, and a dispatcher that calls evaluator modules with explicit schedule/date/input. Kept this inside planning code and avoided public extension or marketplace naming.
