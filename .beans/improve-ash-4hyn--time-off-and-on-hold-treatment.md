---
# improve-ash-4hyn
title: Time-off and on-hold treatment
status: completed
type: task
priority: normal
created_at: 2026-07-04T22:29:03Z
updated_at: 2026-07-04T22:48:41Z
parent: improve-ash-0m50
blocked_by:
    - improve-ash-hmnn
    - improve-ash-hjzi
---

on_hold work renders with distinct muted styling and the time-off window's reason and dates ('Fully off — travel until 12/07'). Sources: session.state.timeOffWindow for sessions, the projector explanation for on-hold tracks. Availability kinds (fully_off vs partial) read differently. Small scope: styling + copy on cards that beans hmnn/hjzi already render.

## Summary of Changes

on_hold work cards get muted styling (flat surface, subdued icon/title); sessions with state.timeOffWindow show a PauseCircle line composing availability ("Fully off"/"Partially off"), reason, and end date; on-hold tracks rely on the projector explanation which already carries the window reason. Note: demo plans have no time-off windows, so this is verified against payload types and compile/checks, not visually — exercise when a time-off window exists.
