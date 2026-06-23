---
# improve-ash-51ij
title: Make Today and AI context frontend ready
status: completed
type: task
priority: normal
created_at: 2026-06-23T09:55:40Z
updated_at: 2026-06-23T10:01:08Z
parent: improve-ash-qdoa
---

Small pre-frontend cleanup pass.\n\n- [x] Make projected sessions reflect started, partial, and completed occurrence/slot state.\n- [x] Lightly group and summarize AI Today context for mixed days.\n- [x] Capture stable offline references as deferred follow-up.\n- [x] Verify with focused tests, story scripts, and mise run verify.

## Summary of Changes\n\n- Project Today now loads slot results and projects sessions as planned, started, partial, completed, skipped, or missed based on persisted occurrence and slot-result state.\n- Projected sessions and AI tool output now include session_state with progress labels such as 1 of 2 logged.\n- Improve.App AI Today context now preserves the flat read-tool data while adding a headline, sections, completed, still_to_do, and missed_or_skipped groups.\n- Added a deferred follow-up bean for stable client-facing offline references: improve-ash-jd16.\n- Tightened order-sensitive journal assertions found during verify.
