---
# improve-ash-svdo
title: Stop leaking internals via broad rescues
status: todo
type: bug
created_at: 2026-07-04T13:20:04Z
updated_at: 2026-07-04T13:20:04Z
parent: improve-ash-fd57
---

~10 catch-all rescue blocks in UiApi turn programming errors into client-visible 422s with raw exception text. Rescue only expected error types; let the rest 500 and log. (notes/fable-todo.md item #15)
