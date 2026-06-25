---
# improve-ash-xkgr
title: Widen target evaluators to decide completion and progress
status: todo
type: feature
priority: high
created_at: 2026-06-25T09:54:47Z
updated_at: 2026-06-25T09:55:17Z
parent: improve-ash-aszg
---

Extend the internal target evaluator shape so it receives the date and bounded journal events, returns completion status/progress plus diagnostics, and moves the existing fixed-target any-event-on-date completion rule behind Improve.Planning.Targets.Fixed. Done when fixed targets still project exactly as before but through the target evaluator path.
