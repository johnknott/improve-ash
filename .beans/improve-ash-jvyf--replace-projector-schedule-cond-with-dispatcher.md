---
# improve-ash-jvyf
title: Replace Projector schedule cond with dispatcher
status: completed
type: task
priority: normal
created_at: 2026-06-24T20:38:19Z
updated_at: 2026-06-24T20:44:25Z
parent: improve-ash-8qr7
---

After schedule evaluator modules and registry metadata exist, simplify the Projector schedule branch to call the internal dispatcher.

Keep the projector responsible for assembling explicit input and projection output, not for knowing each schedule kind.

Done when the old schedule cond is gone and projection output is unchanged.

## Summary of Changes

Replaced the Projector schedule branch with a call to `Improve.Planning.Schedules.decide/3`. The Projector still owns projection flow and input assembly, while schedule-specific decision logic now lives behind the internal dispatcher.
