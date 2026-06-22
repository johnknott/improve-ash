---
# improve-ash-0ksd
title: Implement batch journal ingress result model
status: completed
type: feature
priority: normal
created_at: 2026-06-22T21:38:29Z
updated_at: 2026-06-22T22:53:12Z
parent: improve-ash-vrtx
blocked_by:
    - improve-ash-g8ad
---

Add a headless batch command for pending journal logs with per-command accepted, duplicate, rejected, and needs-resolution results. Acceptance: tests cover mixed batches without rolling back accepted independent commands unnecessarily.

\n\nCompleted: added a headless offline batch ingress command with stable per-entry result structs and statuses for accepted, duplicate, rejected, and needs_resolution outcomes. Mixed-batch tests prove independent accepted entries are not rolled back by rejected or resolution-needed entries. Verification: mise run verify passes with 80 tests.
