---
# improve-ash-w5pw
title: Thread target completion through Projector output
status: todo
type: task
priority: high
created_at: 2026-06-25T09:54:47Z
updated_at: 2026-06-25T09:55:17Z
parent: improve-ash-aszg
blocked_by:
    - improve-ash-xkgr
---

Teach Improve.Planning.Projector to ask implemented target evaluators for completion/progress instead of deciding every track with the old any-linked-event shortcut. ProjectedWork should carry enough progress details for stories/UI serialization while preserving fallback behavior and diagnostics for missing or unknown targets.
