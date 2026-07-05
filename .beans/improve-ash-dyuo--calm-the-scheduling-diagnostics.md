---
# improve-ash-dyuo
title: Calm the scheduling diagnostics
status: todo
type: feature
created_at: 2026-07-05T11:39:29Z
updated_at: 2026-07-05T11:39:29Z
parent: improve-ash-o39y
---

Backend: schedule diagnostics carry the owner's name, and the partial-first-week case (schedule starts/ends mid-week truncating candidates) is severity :info with calm copy ('General Fitness starts this week - 1 session fits before Monday'); genuine constraint conflicts stay :warning. Frontend: non-error diagnostics collapse into a quiet '1 scheduling note' pill above the work list, expandable, with the Review plan setup link inside the expansion; errors stay loud.
