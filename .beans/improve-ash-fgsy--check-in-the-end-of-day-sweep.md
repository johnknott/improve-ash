---
# improve-ash-fgsy
title: 'Check-in: the end-of-day sweep'
status: completed
type: feature
priority: normal
created_at: 2026-07-04T22:57:28Z
updated_at: 2026-07-04T23:38:24Z
parent: improve-ash-qyd7
blocked_by:
    - improve-ash-kt76
---

Product definition (agreed): CheckInDialog lists today's remaining work; each row can be marked done (quick-log semantics for tracks), skipped with optional reason (sessions via skip-session; tracks have no skip endpoint — leave-only for tracks in v1, noted), or left alone; one submit applies all choices sequentially with per-row results. Replaces the stub.

## Summary of Changes
CheckInDialog: end-of-day sweep listing today's remaining work; per-row segmented choice — tracks get Done (quick-log with effective target) / Leave; started sessions get Done (complete) / Skip (with optional reason) / Leave; one Apply runs all choices sequentially with per-row errors. Verified: pending track marked Done → logged, "Check-in saved", dialog closes; empty state ("Everything is wrapped up") renders on a plan with no pending work. Same props_invalid_value fix applied to the skip-note bind.
