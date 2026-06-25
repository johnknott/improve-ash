---
# improve-ash-ogg4
title: Neutralize frontend product screens while backend model settles
status: completed
type: task
created_at: 2026-06-23T21:01:27Z
updated_at: 2026-06-23T21:09:27Z
---

Remove distracting product-specific page bodies and action dialogs from the Svelte frontend while preserving auth, profile completion, app shell, plan switcher, top bar, navigation, and layout.

- [x] Replace product-specific route bodies with neutral queued placeholders
- [x] Replace log/check-in dialogs with queued placeholders
- [x] Remove now-unused product page/dialog imports and deleted old page bodies
- [x] Keep shell, auth, profile, plan switching, date controls, and top bar intact
- [x] Trim the frontend API/types surface to the shell actions still in use
- [x] Run frontend checks/build

Verified with:

- `npm run check`
- `npm run build`
