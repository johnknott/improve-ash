---
# improve-ash-ef2w
title: Track log dialog, old-app style
status: completed
type: feature
priority: normal
created_at: 2026-07-05T11:39:29Z
updated_at: 2026-07-05T12:09:00Z
parent: improve-ash-o39y
blocked_by:
    - improve-ash-1xm9
---

Rebuild the per-track log dialog on the old app's shape: target card (target for the date + the track's own description as guidance), What happened? segmented Record/Skip-today, amount input with READ-ONLY unit chip from the target (unit never sent, never editable in track flows), note behind an Add-note disclosure, dynamic submit label ('Log 3000 steps'). Built as a shared TrackLogStep component so the check-in wizard reuses it per step.

## Summary of Changes
QuickLogDialog replaced by TrackLogDialog + shared TrackLogForm (the wizard-step body for tsld). Old-app shape delivered: header "Log {track} / {plan}", TARGET card (eyebrow "TARGET for Sun 5 Jul", target headline "15 pages", track description as guidance), What happened? segmented Record/Skip today, "How much?" amount with READ-ONLY unit chip (unit never sent — backend resolves from the target), Add note disclosure, dynamic submit ("Log 15 pages" / "Mark done" / "Skip today"). Skip wired to the new skip-track endpoint with optional reason. Client: skipTrack + submitTrackSkip. Verified live: record prefill, label tracking edited amounts ("Log 2 litres"), skip with reason → card "Skipped — Eyes tired tonight.", zero captured errors.

Known limitations, deliberate: checklist-type targets still get the generic amount field (checklist ticking UI arrives with authoring work); note field is record-mode only (skip has its own reason field).
