---
# improve-ash-b8ls
title: Refine top bar date controls
status: completed
type: task
priority: normal
created_at: 2026-06-25T22:41:16Z
updated_at: 2026-06-25T22:42:54Z
---

Move theme toggle from the top bar into the user dropdown, hide Today when already on the selected day, place Today before the date controls when visible, and align calendar controls to button height.

## Summary of Changes\n\nMoved the theme toggle out of the top bar and into the user dropdown. Changed the Today control so it only appears when the selected date is not today, reserves its slot to avoid layout jumps, and sits to the left of the segmented calendar control. Updated the date controls to use the shared button height so they align with Check-in and Log. Verified npm --prefix frontend run check and npm --prefix frontend run build.
