---
# improve-ash-mdo6
title: Implement adaptive target completion
status: todo
type: task
priority: high
created_at: 2026-06-25T09:54:57Z
updated_at: 2026-06-25T09:55:24Z
parent: improve-ash-aszg
blocked_by:
    - improve-ash-xkgr
---

For standalone adaptive tracks, logging an event with the configured adaptive fields counts as done for that date. This is the completion side only; smart suggested payloads remain in recommender/session logic. Include tests that adaptive projection no longer emits unsupported-target diagnostics once implemented.
