---
# improve-ash-u42v
title: Add basic plan creation from the UI
status: completed
type: feature
priority: normal
created_at: 2026-06-23T18:01:47Z
updated_at: 2026-06-23T18:07:47Z
---

Let users create a simple empty plan from the app switcher.\n\n- [x] Add product-shaped app API for creating a plan\n- [x] Add a small New plan dialog\n- [x] Select the created plan after save\n- [x] Keep validation/errors friendly\n- [x] Run verification\n\n## Summary of Changes\n\nAdded POST /api/app/plans through Improve.App.UiApi, backed by Improve.App.create_plan!, and added a New plan dialog opened from the brand plan switcher. New plans are created as draft plans and selected immediately.\n\nVerified with npm run check, npm run build, targeted app controller tests, and mix test.
