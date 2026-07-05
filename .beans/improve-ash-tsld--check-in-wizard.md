---
# improve-ash-tsld
title: Check-in wizard
status: todo
type: feature
created_at: 2026-07-05T11:39:29Z
updated_at: 2026-07-05T11:39:29Z
parent: improve-ash-o39y
blocked_by:
    - improve-ash-ef2w
---

Replace the all-rows sweep with the old app's wizard: intro step (targets / already logged / to review counts) then one step per remaining item - tracks use the shared TrackLogStep (record/skip/next), sessions get a step with slot summary and Complete / Skip session / Leave - then a closing summary and toast. Back/Next navigation, per-step submission (no big-bang apply), skippable everything.
