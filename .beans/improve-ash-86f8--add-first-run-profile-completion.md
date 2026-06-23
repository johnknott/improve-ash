---
# improve-ash-86f8
title: Add first-run profile completion
status: completed
type: feature
priority: normal
created_at: 2026-06-23T18:32:16Z
updated_at: 2026-06-23T18:34:06Z
---

After first sign-in, ask the user for their real name before entering the app.\n\n- [x] Add account/user update action for full name\n- [x] Expose a thin auth/profile API endpoint\n- [x] Add frontend auth client/store support\n- [x] Add blocking Complete Profile page after sign-in\n- [x] Add backend tests and run verification\n\n## Summary of Changes\n\nAdded a named Ash user action, complete_profile, and exposed it through POST /api/auth/profile. First-run users now see a blocking profile page asking for their full name before AppShell loads. The auth store updates the current user after profile completion so the app continues normally.\n\nVerified with auth controller tests, npm run check, npm run build, and mix test.
