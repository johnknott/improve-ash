---
# improve-ash-u392
title: Generic journal events and effects
status: completed
type: epic
priority: high
created_at: 2026-06-22T21:37:18Z
updated_at: 2026-06-22T22:57:39Z
parent: improve-ash-9pfh
---

Move from dose-specific journal pathways toward generic event logging, item links, effect-rule interpretation, and auditable correction. Dose events should become one authored event type rather than a privileged server pathway.\n\nOut of scope: medical guidance, dosage recommendations, or UI form builders.

\n\nCompleted: all child Beans are done. Journal logging now has a generic command shape, a pure effect-rule interpreter, generic event logging, dose logging on top of the generic path, and generic correction/replacement behavior. Verified in prior full project runs, with latest mise run verify passing at 82 tests after subsequent work.
