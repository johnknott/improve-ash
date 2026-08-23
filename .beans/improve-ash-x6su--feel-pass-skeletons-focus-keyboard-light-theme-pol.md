---
# improve-ash-x6su
title: 'Feel pass: skeletons, focus, keyboard, light theme, polish'
status: completed
type: feature
priority: normal
created_at: 2026-07-05T09:33:48Z
updated_at: 2026-08-23T12:56:31Z
parent: improve-ash-i5ps
---

Pulled forward from roadmap Phase 6 quality items: skeleton/loading states instead of spinner-only, focus management + keyboard navigation in dialogs (Escape/Tab order/initial focus), a light-theme sweep of everything built in Phases 1-2, spacing and visual polish debt. Scope after the stability beans land and a day of real use surfaces the rough edges.

## Work Checklist

- [x] Audit loading, keyboard/focus, theme, spacing, and mobile behavior on real Phase 1-2 flows
- [x] Replace weak loading treatment with calm, accessible skeleton states
- [x] Fix demonstrated dialog focus, keyboard, and focus-return issues
- [x] Resolve demonstrated light/dark, spacing, and responsive polish issues
- [x] Run focused browser and automated verification
- [x] Summarize the work and complete Phase 2.5

## Summary of Changes

Replaced spinner-only loading with accessible skeletons and honest initial-error treatment; refreshes now preserve the visible date/plan until their response applies. Dashboard writes are serialized, superseded reads and logout-invalidated writes cannot repopulate or advance stale UI, and profile/network failures keep friendly copy.

Completed the keyboard and dialog pass: initial focus, Escape handling, busy-state close protection, validation focus, disclosure focus, focus return when triggers disappear, and session/card action restoration. Generic logging now exposes required quantity, unit, note, role, and schema fields before submit and focuses useful inline errors.

Completed the light/dark and responsive sweep with an accessible off-canvas mobile sidebar, compact phone toolbar, touch/overflow fixes, reduced-motion behavior, stronger contrast, and visible focus rings through breakpoint transitions. Browser smoke checks covered desktop, tablet, phone, light/dark, delayed/error requests, dialog flows, and session actions; axe reported no WCAG 2 AA violations on the tested screens.

Final `mise run verify` passed: 309 ExUnit tests, TypeScript contract checks, all story scripts, Svelte diagnostics with 0 errors/warnings, and the production frontend build.
