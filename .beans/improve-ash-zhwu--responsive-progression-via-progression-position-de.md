---
# improve-ash-zhwu
title: Responsive progression via progression_position derived metric
status: completed
type: feature
priority: normal
created_at: 2026-07-04T19:43:23Z
updated_at: 2026-07-04T21:29:36Z
parent: improve-ash-xxkf
blocking:
    - improve-ash-m8ry
---

progression_position capability provider computing current step from journal history (advance on success, hold on failure, deload after N misses). Progression targets get two flavors: scheduled (date-indexed) and responsive (performance-gated), defaulting to scheduled. Deload/repeat semantics diagnosable. Story: miss twice holds, pass advances. (notes/coaching-foundations-todo.md item 5)
