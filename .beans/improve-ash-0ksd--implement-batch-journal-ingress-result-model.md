---
# improve-ash-0ksd
title: Implement batch journal ingress result model
status: todo
type: feature
priority: normal
created_at: 2026-06-22T21:38:29Z
updated_at: 2026-06-22T21:38:58Z
parent: improve-ash-vrtx
blocked_by:
    - improve-ash-g8ad
---

Add a headless batch command for pending journal logs with per-command accepted, duplicate, rejected, and needs-resolution results. Acceptance: tests cover mixed batches without rolling back accepted independent commands unnecessarily.
