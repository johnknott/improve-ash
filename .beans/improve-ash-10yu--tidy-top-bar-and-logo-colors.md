---
# improve-ash-10yu
title: Tidy top bar and logo colors
status: completed
type: task
priority: normal
created_at: 2026-06-25T22:36:35Z
updated_at: 2026-06-25T22:38:13Z
---

Remove extra top-bar copy that makes the header too tall, and adjust the golden logo mark to use the dark app background color instead of black.

## Summary of Changes\n\nTightened the top bar by removing the Improve eyebrow and route subtitle from the header, reduced top-bar vertical padding, and adjusted the route title size. Updated logo.svg and favicon.svg so the tracing mark uses the dark app background color (#0d1015), then regenerated priv/static/favicon.ico. Verified npm --prefix frontend run check and npm --prefix frontend run build.
