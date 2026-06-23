---
# improve-ash-8jbf
title: Add direct goal authoring UI
status: in-progress
type: feature
priority: normal
created_at: 2026-06-23T18:01:47Z
updated_at: 2026-06-23T18:11:48Z
---

Let users add and edit simple scheduled direct goals, starting with daily quantity goals like reading 15 minutes.\n\n- [x] Add app API for creating direct goals through Ash resources\n- [x] Add simple direct-goal form with name, quantity, unit, schedule\n- [x] Create or select the backing event type where appropriate\n- [x] Show direct goals in plan detail with add actions\n- [x] Verify projected work appears on selected dates\n- [ ] Add edit support for existing direct goals\n\n## Progress\n\nCreation is implemented end to end: POST /api/app/direct-goals creates a daily direct goal, creates or reuses a backing event type, refreshes the dashboard, and shows the new goal on Today and Plan. Editing remains to finish this Bean.
