---
# improve-ash-xqim
title: Generalize sessions, pools, recommendations, and actuals
status: in-progress
type: epic
priority: normal
tags:
    - backend
    - sessions
created_at: 2026-06-24T12:15:48Z
updated_at: 2026-06-24T12:36:58Z
parent: improve-ash-qdoa
---

## Context

The old gym experience proves a real product need: grouped work, slots, pools, recommendations, swaps, and actual results. The backend should model that pattern generically without gym-specific core verbs.

## Acceptance

- [ ] Sessions are authored with generic slots, pools, items, and environments.
- [ ] Projections preserve recommendation, suggested payload, reason/source, and relevant history.
- [ ] Slot results preserve recommended versus actual item and payload.
- [ ] Story output uses session/slot/recommendation/actual language.
