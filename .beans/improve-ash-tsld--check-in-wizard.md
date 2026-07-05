---
# improve-ash-tsld
title: Check-in wizard
status: completed
type: feature
priority: normal
created_at: 2026-07-05T11:39:29Z
updated_at: 2026-07-05T12:58:47Z
parent: improve-ash-o39y
blocked_by:
    - improve-ash-ef2w
---

Replace the all-rows sweep with the old app's wizard: intro step (targets / already logged / to review counts) then one step per remaining item - tracks use the shared TrackLogStep (record/skip/next), sessions get a step with slot summary and Complete / Skip session / Leave - then a closing summary and toast. Back/Next navigation, per-step submission (no big-bang apply), skippable everything.

## Summary of Changes
Replaced the all-rows sweep with a wizard: intro step (targets / already logged / to review counts, matching the old app) → one step per remaining item → done summary with a "Check-in saved" toast. Tracks reuse the shared TrackLogForm (now with onBack/onLeave props → Back | Leave | dynamic submit); sessions get a new CheckInSessionStep (slot summary + Start session when unstarted, Complete / Skip-with-reason / Leave once started). The queue is frozen at Start so completing an item (which refreshes the dashboard and drops it from today.work) doesn't reshuffle mid-sweep — walk by index. Per-step submission (no big-bang apply); everything skippable/leavable; Back navigates and returns to the intro from step 1.

Verified end-to-end against John's real "Improve myself!" plan: intro counts (6 targets / 2 logged / 4 to review), track Record (Steps → logged, advanced, Today updated to 3 of 6), Leave/advance, session step unstarted (Start session → starts + advances) and started (Back/Leave/Skip/Complete), done summary. Zero captured errors. mise run verify green (309 tests).

Known/deliberate: checklist-target tracks (Daily habits) still get the generic "How much?" amount field in the wizard — the checkbox-list UI is future authoring work; Mark done still records them. Starting a session advances the wizard (starting is progress; slot-by-slot logging stays on the Today card by design).
