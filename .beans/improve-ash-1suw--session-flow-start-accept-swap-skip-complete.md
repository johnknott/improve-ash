---
# improve-ash-1suw
title: 'Session flow: start, accept, swap, skip, complete'
status: completed
type: feature
priority: normal
created_at: 2026-07-04T22:57:28Z
updated_at: 2026-07-04T23:38:24Z
parent: improve-ash-qyd7
blocked_by:
    - improve-ash-u6fx
---

Planned session card → Start session (start-session with template id + date). Started → each slot row gets accept (log-session-slot with recommended item; event key resolved from slot rules server-side), swap (picker over the slot pool's items from planDetail pools/memberships), skip (skip-session-slot). Complete/skip session buttons drive the occurrence transitions. Status mirrors the backend state machine.

## Summary of Changes
SessionSlots: planned session → Start session; started session → per-slot Log (accept recommendation with suggested payload) / Swap (pool-filtered picker) / Skip; session-level Complete/Skip. Verified full flow on gym demo: started, accepted a slot, swapped (Seated Row from Lat Pulldown), skipped Cardio → Partial "2 of 5 logged", then Completed. Required gym-fixture additions: slots now declare default_event and suggested_payload rules so one-tap accept resolves the event type and required sets/reps/duration without per-slot client knowledge. Minor known wart: logged slots reorder to the bottom (backend slot_results ordering) — cosmetic.
