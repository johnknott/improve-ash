---
# improve-ash-ul81
title: Move schedule support diagnostics into registry metadata
status: completed
type: task
priority: normal
created_at: 2026-06-24T20:38:06Z
updated_at: 2026-06-24T20:44:25Z
parent: improve-ash-8qr7
---

Represent implemented, recognized-unsupported, and unknown schedule tiers as internal registry metadata instead of scattered condition branches.

Keep user-facing diagnostics plain-English and equivalent or better than today.

Done when unsupported/custom schedule messages still tell the truth without hard-coded diagnostic branches in the main projector flow.

## Summary of Changes

Moved schedule support tiers into the internal schedule dispatcher: implemented evaluator modules, recognized-but-unsupported kinds, and unknown kinds. Existing diagnostic codes/messages remain preserved.
