---
# improve-ash-himh
title: Fix jumpy view transitions
status: completed
type: bug
priority: normal
created_at: 2026-06-25T23:02:45Z
updated_at: 2026-06-25T23:03:45Z
---

The CSS view transition started smooth but now appears to jump during route changes. Limit the transition to intended page content and remove layout-sensitive motion.

## Summary of Changes\n\nFixed the jump/black flicker risk in CSS View Transitions by setting the document and transition overlay background to the app background, disabling the default root snapshot animation, clipping the named page-content transition group, and simplifying page-content motion to a pure opacity crossfade. Verified npm --prefix frontend run check and npm --prefix frontend run build.
