---
# improve-ash-u6fx
title: 'Write-path client: endpoints, patches, backend gaps'
status: todo
type: task
created_at: 2026-07-04T22:57:28Z
updated_at: 2026-07-04T22:57:28Z
parent: improve-ash-qyd7
blocked_by:
    - improve-ash-xmsc
---

Backend: add POST /app/log-track (UiApi wrapper over App.log_track!, patch [today, journal]), POST /app/skip-session-slot (App.skip_session_slot!, patch), and upgrade UiApi.log_event to return patch + event. Frontend: typed improveClient functions for log-track, log-event, log-linked-event, start-session, log/swap/skip-session-slot, complete/skip-session, correct-linked-event; dashboardState mutation wrappers with refreshing state, applyDashboardPatch, toast, and rethrow-for-forms.
