---
# improve-ash-otsx
title: Handle stale plan references in offline logs
status: todo
type: task
priority: low
created_at: 2026-06-22T21:38:29Z
updated_at: 2026-06-22T21:38:58Z
parent: improve-ash-vrtx
blocked_by:
    - improve-ash-0ksd
---

Define and test how the server responds when an offline log references archived, missing, or changed plan/session/slot/direct-goal records. Acceptance: stale references produce clear rejection or resolution-needed results rather than silent bad data.
