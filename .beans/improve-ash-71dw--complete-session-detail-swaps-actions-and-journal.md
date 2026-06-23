---
# improve-ash-71dw
title: Complete session detail, swaps, actions, and journal context
status: completed
type: feature
priority: normal
created_at: 2026-06-23T15:56:42Z
updated_at: 2026-06-23T16:02:35Z
---

Build the next gym-session UI slice.\n\n- [x] Add a focused session detail view reachable from Today\n- [x] Support same-pool slot swaps while preserving recommended vs actual items\n- [x] Add complete and skip session actions\n- [x] Enrich journal entries with item, session, slot, and effect context\n- [x] Run frontend and backend verification

## Summary of Changes\n\n- Added a focused session detail view reachable from Today via View.\n- Added same-pool swap support for session slot results before logging.\n- Added complete and skip session app endpoints and UI actions.\n- Enriched journal entries with linked items, slot context, and item effects.\n- Verified with npm run check, npm run build, and mix test.
