---
# improve-ash-7vv6
title: Make favicon outside corners transparent
status: completed
type: task
priority: normal
created_at: 2026-06-25T13:11:20Z
updated_at: 2026-06-25T13:16:33Z
---

Adjust the new logo/favicon SVGs so the area outside the rounded mark remains transparent while the internal cut-out still reads correctly.

## Summary of Changes\n\nReplaced the hand-drawn white arrow overlay with a white rounded backing behind the original mark, preserving the original arrow cut-out geometry while keeping the favicon corners transparent. Regenerated priv/static/favicon.ico from the corrected SVG and verified npm --prefix frontend run check plus npm --prefix frontend run build.
