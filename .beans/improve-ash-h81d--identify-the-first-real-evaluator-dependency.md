---
# improve-ash-h81d
title: Identify the first real evaluator dependency
status: draft
type: task
priority: normal
created_at: 2026-06-24T20:38:31Z
updated_at: 2026-06-24T20:38:31Z
parent: improve-ash-o1ro
blocked_by:
    - improve-ash-z91i
---

Do not build dependency graph machinery in the abstract. First identify a concrete evaluator that needs another evaluator output, such as adaptation consuming a derived metric.

Done when the dependency is described with real inputs, outputs, and why direct calculation inside the consumer would be wrong.
