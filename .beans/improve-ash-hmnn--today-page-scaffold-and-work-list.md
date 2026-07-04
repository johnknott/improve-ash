---
# improve-ash-hmnn
title: Today page scaffold and work list
status: completed
type: feature
priority: normal
created_at: 2026-07-04T22:28:41Z
updated_at: 2026-07-04T22:35:39Z
parent: improve-ash-0m50
---

Replace PlaceholderPage on the today route with a real Today page under frontend/src/features/today/. Introduce the route → component map in AppShell (first real page; other routes keep PlaceholderPage). Render today.work as cards: title, kind (track/session), status badge covering the full vocabulary (planned / started / partial / completed / missed / on_hold / skipped), the projector's explanation line as schedule context ('every Tuesday'), and plan/date context from the today slice store. Subscribe to the sliced stores from Phase 0 (today, dashboardStatus) — not the combined dashboardData.
