---
# improve-ash-wh9b
title: Journal read page and event detail
status: completed
type: feature
priority: normal
created_at: 2026-08-23T12:58:45Z
updated_at: 2026-08-23T13:24:20Z
parent: improve-ash-znu0
---

Build the real Phase 3 Journal surface around the durable event history. Use a composed Phoenix page payload where it is clearer than forcing a screen into a fake resource; reuse Improve.Journal/Ash reads and policies for ownership and ordering. The page should be newest-first, filterable, paginated, and able to reveal event payload, linked items, effects, and correction relationships in product language.

## Work Checklist

- [x] Audit installed journal reads, pagination, relationships, API payloads, and route state
- [x] Add the Journal page read contract and focused backend tests
- [x] Add frontend types, client/state loading, filters, and pagination
- [x] Build the responsive Journal list, empty/error states, and event detail interaction
- [x] Expose correction eligibility without implementing alternate correction rules in the UI
- [x] Run focused browser and automated verification
- [x] Summarize changes and complete the Bean

## Summary

Added an authenticated, plan-scoped Journal page contract with deterministic newest-first pagination, server-owned cursors, event/track/item/status filters, full event detail, correction lineage, and backend-owned correction eligibility reasons. Added focused API coverage for ownership, pagination, filters, detail, lineage, eligibility, and validation.

Built a dedicated guarded Svelte Journal state and responsive page with filter and pagination controls, complete loading/empty/error states, and a keyboard-accessible Bits UI event-detail dialog. The detail view exposes payloads, linked items, state effects, corrected/voided timestamps, and correction history without duplicating backend correction rules.

Verified the slice through focused API and frontend checks, desktop/mobile browser scenarios, light/dark themes, pagination and correction flows, keyboard focus, and an axe pass with no violations. Final `mise run verify` passed with 314 ExUnit tests, clean Svelte/TypeScript checks, story scripts, and a production frontend build.
