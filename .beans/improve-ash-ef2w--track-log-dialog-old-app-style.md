---
# improve-ash-ef2w
title: Track log dialog, old-app style
status: todo
type: feature
created_at: 2026-07-05T11:39:29Z
updated_at: 2026-07-05T11:39:29Z
parent: improve-ash-o39y
blocked_by:
    - improve-ash-1xm9
---

Rebuild the per-track log dialog on the old app's shape: target card (target for the date + the track's own description as guidance), What happened? segmented Record/Skip-today, amount input with READ-ONLY unit chip from the target (unit never sent, never editable in track flows), note behind an Add-note disclosure, dynamic submit label ('Log 3000 steps'). Built as a shared TrackLogStep component so the check-in wizard reuses it per step.
