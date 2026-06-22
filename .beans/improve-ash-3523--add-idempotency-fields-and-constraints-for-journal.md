---
# improve-ash-3523
title: Add idempotency fields and constraints for journal events
status: todo
type: feature
priority: normal
created_at: 2026-06-22T21:38:29Z
updated_at: 2026-06-22T21:38:58Z
parent: improve-ash-vrtx
blocked_by:
    - improve-ash-g8ad
---

Persist enough client-origin metadata to make offline event retries safe. Acceptance: duplicate client operation submissions for the same user/device return or identify the original event instead of creating duplicates.
