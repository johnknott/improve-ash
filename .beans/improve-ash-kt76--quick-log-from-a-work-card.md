---
# improve-ash-kt76
title: Quick log from a work card
status: completed
type: feature
priority: normal
created_at: 2026-07-04T22:57:28Z
updated_at: 2026-07-04T23:38:24Z
parent: improve-ash-qyd7
blocked_by:
    - improve-ash-u6fx
---

canLog track cards get a Log button → small prefilled dialog (quantity/unit from target, note) → confirm → log-track. Progress and status update from the returned patch immediately.

## Summary of Changes
QuickLogDialog: canLog track cards get a Log button → dialog prefilled with target quantity/unit → log-track. Status/progress update from the returned patch (verified: Reading track flipped to Completed on submit). App.log_track! now backfills the payload amount/unit from resolved quantity so target-default logs validate.
