---
# improve-ash-sdil
title: Slightly enlarge logo circle
status: completed
type: task
priority: normal
created_at: 2026-06-25T23:13:39Z
updated_at: 2026-06-25T23:14:11Z
---

Increase the golden circle size in the frontend logo/favicon while keeping the inner mark the same size.

## Summary of Changes\n\nIncreased the golden circle radius in frontend/public/logo.svg and frontend/public/favicon.svg from 470 to 490 while leaving the inner mark transform/path unchanged. Regenerated priv/static/favicon.ico and verified npm --prefix frontend run check plus npm --prefix frontend run build.
