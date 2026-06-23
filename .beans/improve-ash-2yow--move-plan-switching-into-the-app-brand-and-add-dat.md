---
# improve-ash-2yow
title: Move plan switching into the app brand and add date navigation
status: completed
type: feature
priority: normal
created_at: 2026-06-23T18:01:47Z
updated_at: 2026-06-23T18:04:46Z
---

Make the app navigable like a normal product.\n\n- [x] Replace the separate current-plan sidebar card with a brand-area plan switcher\n- [x] Include a visible New plan affordance in the switcher menu\n- [x] Add selected-date state and a topbar date control\n- [x] Reload dashboard projections when plan or date changes\n- [x] Preserve existing session/logging behavior\n- [x] Run frontend/backend verification\n\n## Summary of Changes\n\nMoved plan switching into the sidebar brand area, removed the separate current-plan card, added a New plan menu affordance, and introduced selected-date state with previous/next/today/date-input controls. Dashboard-returning commands now carry the selected date so the UI does not snap back to calendar today after actions.\n\nVerified with npm run check, npm run build, and mix test.
