---
# improve-ash-1suw
title: 'Session flow: start, accept, swap, skip, complete'
status: todo
type: feature
created_at: 2026-07-04T22:57:28Z
updated_at: 2026-07-04T22:57:28Z
parent: improve-ash-qyd7
blocked_by:
    - improve-ash-u6fx
---

Planned session card → Start session (start-session with template id + date). Started → each slot row gets accept (log-session-slot with recommended item; event key resolved from slot rules server-side), swap (picker over the slot pool's items from planDetail pools/memberships), skip (skip-session-slot). Complete/skip session buttons drive the occurrence transitions. Status mirrors the backend state machine.
