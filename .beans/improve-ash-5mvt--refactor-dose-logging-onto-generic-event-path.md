---
# improve-ash-5mvt
title: Refactor dose logging onto generic event path
status: todo
type: task
priority: high
created_at: 2026-06-22T21:37:54Z
updated_at: 2026-06-22T21:38:47Z
parent: improve-ash-u392
blocked_by:
    - improve-ash-jrrn
---

Make the vial dose scenario use the generic event/effect pathway while keeping the public spike scenario intact. Acceptance: dose log and correction tests still pass and no vial-specific effect creation remains in the orchestration layer except fixture convenience code.
