---
# improve-ash-grxa
title: Atomic state transitions
status: todo
type: bug
created_at: 2026-07-04T13:20:05Z
updated_at: 2026-07-04T13:20:05Z
parent: improve-ash-fd57
---

data_one_of check-then-set on session/slot/event transitions is racy; require_atomic? false widespread. Move guards into atomic updates where Ash allows. (notes/fable-todo.md item #18)
