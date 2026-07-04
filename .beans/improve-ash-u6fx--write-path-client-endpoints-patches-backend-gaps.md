---
# improve-ash-u6fx
title: 'Write-path client: endpoints, patches, backend gaps'
status: completed
type: task
priority: normal
created_at: 2026-07-04T22:57:28Z
updated_at: 2026-07-04T23:38:24Z
parent: improve-ash-qyd7
blocked_by:
    - improve-ash-xmsc
---

Backend: add POST /app/log-track (UiApi wrapper over App.log_track!, patch [today, journal]), POST /app/skip-session-slot (App.skip_session_slot!, patch), and upgrade UiApi.log_event to return patch + event. Frontend: typed improveClient functions for log-track, log-event, log-linked-event, start-session, log/swap/skip-session-slot, complete/skip-session, correct-linked-event; dashboardState mutation wrappers with refreshing state, applyDashboardPatch, toast, and rethrow-for-forms.

## Summary of Changes
Backend: added POST /app/log-track (UiApi.log_track over App.log_track!, patch [today, journal], idempotency threaded into log_track!), POST /app/skip-session-slot (App.skip_session_slot!), and upgraded log_event to return a [today, journal] patch + event. Frontend: typed improveClient functions for all write ops + dashboardState mutation wrappers (runMutation: refreshing, applyDashboardPatch, toast, rethrow-for-forms). Two new controller tests. Fixed three latent backend bugs found by driving the real flow: (1) slot_result_json.poolName was always null; (2) log_session_slot_event always set role: nil, overriding the slot's default_role resolution — event/role now fall back to slot rules; (3) slot-log validation raised CommandError → 500, now rescued to 422.
