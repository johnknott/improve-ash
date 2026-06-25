---
# improve-ash-1vgw
title: Replace webapp logo and favicon
status: completed
type: task
priority: normal
created_at: 2026-06-25T13:05:56Z
updated_at: 2026-06-25T13:10:17Z
---

Use the supplied ~/logo.svg for the webapp brand mark, trim excessive whitespace if needed, and create a favicon variant without the Improve text.

## Summary of Changes\n\nReplaced the plan-switcher brand badge with a cropped mark derived from /home/john/Logo.svg, added frontend/public/logo.svg, replaced the SVG favicon with a text-free cropped mark, and refreshed the tracked priv/static/favicon.ico fallback from the same mark. Verified with rsvg-convert previews plus npm --prefix frontend run check and npm --prefix frontend run build.
