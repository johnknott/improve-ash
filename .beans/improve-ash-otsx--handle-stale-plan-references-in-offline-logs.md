---
# improve-ash-otsx
title: Handle stale plan references in offline logs
status: completed
type: task
priority: low
created_at: 2026-06-22T21:38:29Z
updated_at: 2026-06-22T22:57:00Z
parent: improve-ash-vrtx
blocked_by:
    - improve-ash-0ksd
---

Define and test how the server responds when an offline log references archived, missing, or changed plan/session/slot/direct-goal records. Acceptance: stale references produce clear rejection or resolution-needed results rather than silent bad data.

\n\nCompleted: added offline preflight handling for stale plan references. Missing records, cross-plan references, archived plans/items, completed sessions, and already-linked or completed slot results now return needs_resolution with stable conflict categories instead of silently writing bad journal data. Verification: mise run verify passes with 82 tests.
