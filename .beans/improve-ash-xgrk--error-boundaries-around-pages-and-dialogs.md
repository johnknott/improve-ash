---
# improve-ash-xgrk
title: Error boundaries around pages and dialogs
status: completed
type: feature
priority: normal
created_at: 2026-07-05T09:33:48Z
updated_at: 2026-07-05T09:40:48Z
parent: improve-ash-i5ps
blocked_by:
    - improve-ash-6401
---

Svelte 5 <svelte:boundary> around the AppShell page area and each dialog: a component crash renders an inline error card with a retry (reset) instead of silently wedging the subtree (the props_invalid_value failure mode). onerror reports into the dev error buffer.

## Summary of Changes
svelte:boundary around the AppShell page area (failed → inline card with message + Try again/reset) and around each of LogDialog/CheckInDialog/NewPlanDialog (shared failed snippet → fixed danger bar with Dismiss that resets UI state then remounts). onerror reports into the dev error buffer. Permanent one-shot crash hook in PlaceholderPage (sessionStorage improve-crash-test) for testing boundaries. Verified live: deliberate crash → contained card, sidebar/topbar alive, badge lit; Try again → page recovered. This retires the wedged-subtree failure mode from Phase 2.
