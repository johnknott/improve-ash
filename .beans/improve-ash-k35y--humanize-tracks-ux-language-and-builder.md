---
# improve-ash-k35y
title: Humanize tracks UX language and builder
status: completed
type: feature
priority: normal
created_at: 2026-06-23T19:45:39Z
updated_at: 2026-06-23T19:51:05Z
---

Make the product UI speak in friendly Tracks language instead of exposing direct-goal/domain internals.

- [x] Audit current Today/Plan/logging wording around goals, tracks, resources, and event types
- [x] Rename the plan-facing direct-goal UI to Tracks
- [x] Replace the basic goal form with a first-pass friendly track builder
- [x] Keep backend direct-goal APIs stable unless the UX exposes a real model gap
- [x] Run frontend and backend checks

## Summary of Changes

- Replaced the plan-facing Add Goal dialog with an Add Track dialog.
- Added working Fixed amount and Record metric track modes.
- Left Progression, Period total, and Checklist visible as upcoming track modes rather than pretending they are wired.
- Let metric tracks store a unit and metric name without a fixed target quantity.
- Updated Today logging so metric tracks ask for a recorded value.
- Kept the backend resource model as direct goals, event types, schedules, and journal events rather than recreating old overloaded tracks.

## Deferred

- Progression tracks need backend progression modelling.
- Period totals need aggregate progress/projected goal modelling.
- Checklist tracks need a payload/logging shape and projection semantics.
- Linked resources should become a track-builder advanced section once resource/event authoring is friendly enough.
