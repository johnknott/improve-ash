---
# improve-ash-qyd7
title: 'Frontend Phase 2: logging, write side'
status: in-progress
type: epic
created_at: 2026-07-04T22:57:28Z
updated_at: 2026-07-04T22:57:28Z
---

Phase 2 of notes/frontend-roadmap.md: the write side that makes the app daily-usable. Quick log from work cards, the real LogDialog, session flow (start/accept/swap/skip slots/complete), check-in as the end-of-day sweep (product definition agreed with John: remaining work listed, each item mark-done / skip-with-reason / leave, one submit), corrections (slip candidate — pairs with Phase 3 Journal). All backend endpoints exist with idempotency (bean fian); three small additions needed: log-track endpoint (App.log_track! has no HTTP route), skip-session-slot endpoint (App.skip_session_slot! has no route), and log_event returning a dashboard patch.
