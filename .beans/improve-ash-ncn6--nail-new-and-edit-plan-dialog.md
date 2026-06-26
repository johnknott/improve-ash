---
# improve-ash-ncn6
title: Nail new and edit plan dialog
status: completed
type: task
priority: normal
created_at: 2026-06-25T23:19:53Z
updated_at: 2026-06-25T23:27:03Z
---

Improve the plan dialog so users can define start date plus either duration or end date, choose duration units, and prepare the shape for both new and edit plan flows.


## Summary of Changes

- Reworked the plan dialog around the old-app flow: plan name, start date, duration/end-date mode, duration value, and units.
- Reused the same dialog for editing the current plan from the plan switcher, with prefilled values and save/update copy.
- Added a thin PATCH /api/app/plans/:plan_id route through UiApi to the existing Ash Plan update action.
- Added controller coverage proving signed-in users can update their own plan container and get the refreshed dashboard payload.

## Verification

- npm --prefix frontend run check
- npm --prefix frontend run build
- mix test test/improve_web/app_controller_test.exs
- mix test
