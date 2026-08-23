---
# improve-ash-362d
title: Today page tidy
status: completed
type: task
priority: normal
created_at: 2026-07-05T11:39:29Z
updated_at: 2026-08-23T12:14:56Z
parent: improve-ash-o39y
blocked_by:
    - improve-ash-dyuo
    - improve-ash-ybkv
---

Layout pass once diagnostics are calm and cards speak product language: summary line placement, diagnostics pill position, card spacing/hierarchy polish, progress line treatment for quantitative targets (consult the dataviz skill before any meter styling). Kept deliberately after real-use feedback on the other beans.

## Note from ef2w verification
The day summary counts skipped items as "remaining" ("1 of 2 done · 1 remaining" when the other item was consciously skipped). Consider treating skipped as handled: "1 done · 1 skipped" — likely a small backend tweak to today counts or a frontend-side derivation from work statuses.

## Work checklist

- [x] Confirm Today count semantics and visual baseline
- [x] Implement honest handled/skipped/remaining summary
- [x] Polish Today hierarchy, spacing, diagnostics, and progress treatment
- [x] Verify focused backend and frontend checks
- [x] Summarize changes and complete the Bean

## Summary of Changes

- Made the Today API return explicit completed, skipped, missed, on-hold, and genuinely remaining counts, with controller coverage for planned, skipped, and completed states.
- Reworked the Today summary and visual hierarchy, clarified target and checklist progress without adding a decorative meter, improved upcoming-work semantics, and reduced completed/skipped card emphasis.
- Fixed narrow session cards and slot actions so they wrap without overflow, and kept session mutations on the date the user was viewing.
- Verified the result in light and dark themes at desktop and 390px widths. `mise run verify` passed with 309 ExUnit tests, story scripts, generated-contract checks, frontend checks, and the production build.
