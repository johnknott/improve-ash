---
# improve-ash-hd5f
title: Review internal evaluator namespace after two kinds
status: completed
type: task
priority: normal
created_at: 2026-06-24T20:38:31Z
updated_at: 2026-06-24T20:52:00Z
parent: improve-ash-z91i
blocked_by:
    - improve-ash-8qr7
---

After schedule and one second evaluator kind exist, decide whether the code should remain under planning-specific namespaces or move toward a broader internal evaluator namespace.

Avoid extension/marketplace naming unless the code genuinely needs it.

Done when module names reflect the actual internal scope.

## Summary of Changes

Reviewed the namespace after schedule and target evaluator kinds. Decision: keep the code in planning-specific internal namespaces for now.

Current shape:
- `Improve.Planning.Schedules` owns schedule projection dispatch and schedule evaluator modules.
- `Improve.Planning.Targets` owns target projection diagnostics and target evaluator modules.

Rationale:
- Both evaluator kinds are still planner concerns, not an extension or marketplace API.
- The code is clearer when the namespace names the product decision being made.
- A broad `Improve.Extensions` or generic evaluator namespace would imply maturity and public surface area the code has not earned yet.

Next namespace checkpoint: revisit only after a real third kind or an evaluator dependency forces shared host machinery.
