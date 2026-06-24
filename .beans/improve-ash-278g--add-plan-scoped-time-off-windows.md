---
# improve-ash-278g
title: Add plan-scoped time-off windows
status: completed
type: feature
priority: high
created_at: 2026-06-24T21:48:43Z
updated_at: 2026-06-24T21:58:24Z
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



## Implementation Checklist

- [x] Inspect existing plan resources, App helpers, story helpers, and projection inputs.
- [x] Add the durable plan-scoped time-off model and migration.
- [x] Expose App/Story add_time_off! helpers.
- [x] Thread time-off windows into projection as explicit input.
- [x] Treat fully_off windows as planned time off in projected work.
- [x] Prove the marathon holiday path with runnable tests/story assertions.
- [x] Run backend verification and update this bean with the summary.



## Summary of Changes

Added a plan-scoped TimeOffWindow resource with a generated AshPostgres migration and snapshot. Exposed App.add_time_off!/2 and Story.add_time_off!/3 so product stories can declare holidays without using journal events. Plans.project_today/2 now loads time_off_windows into the explicit pure projection input, and the projector treats fully_off windows as on_hold projected work rather than missed/planned work. The projected payload includes the matching time-off window metadata. Completed track history still wins if the user logged work anyway. The backend UI JSON marks on_hold track work as not directly loggable.

Story 10 now executes a real summer_holiday time-off window and projects the long run on 2026-08-16 as on_hold.

Verification:
- mix test test/improve/planning/project_today_test.exs test/improve/stories/stories_test.exs
- MIX_ENV=test mix run priv/scripts/stories/10_adaptive_marathon.exs
- mix test test/improve_web/app_controller_test.exs
- mise run fmt
- mise run lint
- mise run test
- mix ash_typescript.codegen --check
- mise run typescript:check
- mise run stories:run
