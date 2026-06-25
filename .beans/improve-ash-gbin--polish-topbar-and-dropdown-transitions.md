---
# improve-ash-gbin
title: Polish topbar and dropdown transitions
status: completed
type: task
priority: normal
created_at: 2026-06-25T22:58:01Z
updated_at: 2026-06-25T23:00:06Z
---

Align date controls exactly with top-bar button height, tune dropdown item text colors to match sidebar nav until hover, and add lightweight CSS view transitions.

## Summary of Changes\n\nAligned the date segmented control to the shared button height by making it border-box and giving child controls full height. Added lightweight CSS view transitions for page content on route changes, respecting reduced-motion. Tuned dropdown row text to use muted sidebar-style text by default and brighten on hover/highlight, with gold retained for action icons and selected-plan checks. Verified npm --prefix frontend run check and npm --prefix frontend run build.
