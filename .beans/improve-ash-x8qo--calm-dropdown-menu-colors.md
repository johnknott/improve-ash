---
# improve-ash-x8qo
title: Calm dropdown menu colors
status: completed
type: task
priority: normal
created_at: 2026-06-25T22:47:16Z
updated_at: 2026-06-25T22:47:42Z
---

Adjust dropdown item colors so menu text uses normal readable foreground colors in both themes, with gold reserved for icons/accent states, and darken the light-mode gold accent if needed.

## Summary of Changes\n\nChanged dropdown action rows so their text uses the normal theme foreground while icons continue to use the gold accent. Darkened the light-mode --brand-strong token from #e0ad2a to #b88305 so gold accents read better on light surfaces. Verified npm --prefix frontend run check and npm --prefix frontend run build.
