---
# improve-ash-ao2w
title: Top-bar Log chooser and generic dialog cleanup
status: completed
type: feature
priority: normal
created_at: 2026-07-05T12:14:57Z
updated_at: 2026-07-05T12:19:14Z
parent: improve-ash-o39y
---

John's finding: the top-bar Log button (most prominent entry point) opens the raw generic event form — the new track dialog only lives on track cards. Old-app pattern: Log is a menu. Top-bar Log becomes a dropdown listing today's loggable tracks (each opens TrackLogDialog, now a single global instance driven by uiState.trackLogItem) with the generic form demoted to 'Something else…'. Generic LogDialog gets progressive disclosure: required schema fields and required roles up front; optional fields, optional roles, and note behind a 'More details' toggle; 'optional' rendered inline in field labels (new Field optional prop) instead of stray hint lines.

## Summary of Changes
Top-bar Log is now a menu: "Scheduled today" lists today's loggable tracks (title + target summary, e.g. "Reading — 15 pages"), each opening the new TrackLogDialog; the generic event form is demoted to "Something else…". TrackLogDialog became a single global instance driven by uiState.trackLogItem (cards and the menu both route through openTrackLog), wrapped in its own error boundary. Generic LogDialog gained progressive disclosure: Event type + Date, required roles, required schema fields (and quantity/unit only when the schema requires an amount) up front; optional roles/fields, quantity, and note behind "More details…"; stray "Optional" hint lines replaced by an inline optional marker on labels (Field optional prop). Gym user's "Log an event" went from eleven visible inputs to five. Verified live as both the gym user (menu → generic form) and a track user (menu lists only still-loggable tracks — completed ones drop out, skipped ones stay; menu item opens the track dialog with target card). Zero captured errors.
