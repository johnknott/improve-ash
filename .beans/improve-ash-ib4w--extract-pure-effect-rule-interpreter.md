---
# improve-ash-ib4w
title: Extract pure effect rule interpreter
status: todo
type: feature
priority: high
created_at: 2026-06-22T21:37:54Z
updated_at: 2026-06-22T21:37:54Z
parent: improve-ash-u392
---

Move effect rule interpretation into a pure module that receives event type rules, item links, payload, and timestamps, then returns effect specs and diagnostics. Acceptance: interpreter has unit tests and does not read the database or mutate history.
