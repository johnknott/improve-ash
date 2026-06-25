---
# improve-ash-8e5j
title: V1 backend readiness
status: completed
type: milestone
priority: high
created_at: 2026-06-25T09:54:05Z
updated_at: 2026-06-25T10:58:55Z
---

Make the backend V1-ready without redoing already-finished foundation work. Done means the product vocabulary projects honestly, review can apply at least the concrete durable proposal we support, verification catches stories by default, and cheap API/naming hardening is complete.

Scope:
- all V1 target shapes decide completion/progress
- monthly and every-N-weeks schedules project
- review/proposal/apply loop works for extend_plan
- backend verification and API negative tests are tightened

Out of scope for this milestone:
- UI feature work
- public extension API, marketplace, sandbox, billing, admin, or full offline sync
- offline batch ingress over HTTP, tracked separately for V1.1

- Summary of Changes: V1 backend readiness milestone completed. Target projection now decides completion/progress for fixed, metric, checklist, period-total, progression, and adaptive targets; monthly and every-N-weeks schedules project; review proposals can apply the supported extend_plan edit and re-project against the new plan end date; default verify now runs stories; Phoenix app-controller negative tests were added; stale direct_goals/spike wording was swept. Offline batch ingress over HTTP remains tracked as V1.1 scope, not part of this milestone. Full mise run verify is green.
