---
# improve-ash-6h6g
title: Align user and plan dropdown triggers
status: completed
type: task
priority: normal
created_at: 2026-06-25T22:49:54Z
updated_at: 2026-06-25T22:50:32Z
---

Make the user dropdown trigger and plan dropdown trigger visually consistent, especially around border/background treatment.

## Summary of Changes\n\nUpdated the sidebar user dropdown trigger to match the plan dropdown trigger's bordered surface treatment: border, surface background, padding, hover/open background, and border-color transition. Also added standard data-state=open selectors so Bits UI open-state styling applies consistently. Verified npm --prefix frontend run check and npm --prefix frontend run build.
