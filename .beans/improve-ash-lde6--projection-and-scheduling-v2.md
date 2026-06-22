---
# improve-ash-lde6
title: Projection and scheduling V2
status: completed
type: epic
priority: high
created_at: 2026-06-22T21:37:18Z
updated_at: 2026-06-22T22:57:39Z
parent: improve-ash-9pfh
---

Make projection match the broader product model from notes/full-rewrite-spec.md. Sessions and direct goals should share scheduling vocabulary, projection should account for history where needed, and diagnostics should explain schedules that cannot be placed.\n\nOut of scope: UI calendar interactions and notification delivery.

\n\nCompleted: all child Beans are done. Projection now has a shared projected-work output, direct-goal input loading and projection, quota scheduling semantics, and diagnostics for unplaceable schedules. Verified in prior full project runs, with latest mise run verify passing at 82 tests after subsequent work.
