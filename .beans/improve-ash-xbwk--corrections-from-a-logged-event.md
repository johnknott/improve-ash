---
# improve-ash-xbwk
title: Corrections from a logged event
status: completed
type: feature
priority: normal
created_at: 2026-07-04T22:57:28Z
updated_at: 2026-08-23T14:21:56Z
parent: improve-ash-znu0
blocked_by:
    - improve-ash-lgjr
    - improve-ash-wh9b
---

'Fix this' on an eligible logged event → edit dialog seeded with original values → the general correction endpoint creates the replacement and marks the original corrected. The backend derives links, effects, and session context from the original event. Ordinary and gym events with no effects, plus stateful events with one linked active effect, are supported. Ambiguous multi-effect events remain read-only and explain why.

## Work Checklist

- [x] Confirm the Journal detail contract exposes backend-owned correction eligibility and source values
- [x] Tighten the correction request/response contract and focused backend tests where needed
- [x] Add typed frontend correction submission and guarded refresh behavior
- [x] Build the accessible edit-and-confirm correction dialog from Journal detail
- [x] Verify eligible, ineligible, lineage, validation, focus, mobile, and theme scenarios
- [x] Run the handoff suite, summarize the work, and complete the Bean

## Summary of Changes

- Added a backend-owned correction context and general correction API that preserves the original event, creates an auditable replacement, and returns the normal dashboard refresh slices.
- Added safe session-slot relinking so corrected gym results keep their completion state, chosen item, and corrected workout payload.
- Added a typed Journal correction form with schema-derived fields, unchanged and required-field guards, clear history language, responsive layout, and reliable keyboard focus.
- Added focused API coverage for ordinary, stateful inventory, and completed gym corrections, plus invalid timestamps, ownership, stale history, and atomic no-write failures.
- Verified 14 focused correction and Journal tests, the full 319-test handoff suite, frontend type/build checks, a real chained gym correction in the browser, mobile layout, keyboard focus, and an axe scan with no violations.
