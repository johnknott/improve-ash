---
# improve-ash-278g
title: Add plan-scoped time-off windows
status: todo
type: feature
priority: high
created_at: 2026-06-24T21:48:43Z
updated_at: 2026-06-24T21:48:43Z
parent: improve-ash-97ij
---

Add the backend primitive behind the story-level add_time_off! call used by the adaptive marathon plan. This is internal/product-model work only; UI remains deferred.

Scope:
- Add plan-owned time-off windows with clear product fields: starts_on, ends_on, reason/key, and availability such as fully_off.
- Expose a product-facing App.add_time_off! helper for stories and tests.
- Include time-off windows in projection inputs without making the projection code read the database.
- Teach projection that fully_off windows suppress planned work as planned time off, not missed or failed work.
- Cover the marathon holiday scenario with runnable tests/story assertions.

Out of scope for this bean:
- Rich adaptation proposals, extend_plan commits, illness/injury logic, or capability graph work.
- UI.

Done when story 10 can execute a real holiday/time-off call and the backend tests prove planned work is treated differently during time off.
