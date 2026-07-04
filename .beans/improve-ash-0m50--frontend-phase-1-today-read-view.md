---
# improve-ash-0m50
title: 'Frontend Phase 1: Today read view'
status: completed
type: epic
priority: normal
created_at: 2026-07-04T22:28:31Z
updated_at: 2026-07-04T22:48:41Z
---

Phase 1 of notes/frontend-roadmap.md: the screen users see most — render the projection honestly. Work list, session cards, target progress with effective-target provenance, time-off styling, diagnostics/explanations, upcoming strip, empty states. Backend dependencies (effective targets, provenance, evaluator pipelines in project_today) all landed via the coaching-foundations epic (improve-ash-xxkf). Builds on the Phase 0 data layer (improve-ash-3jq6): today slice store, TargetProgress union, form kit not needed here — this phase is read-only.

## Summary of Changes

All seven children completed in one pass. Today is a real page: work list with status vocabulary, session cards with slot-grouped recommendations (required a ui_api.ex payload restructure + latent poolName bug fix), target progress with provenance typing, time-off treatment, diagnostics/explanations, upcoming strip, and rest-day/no-plan empty states. mise run verify green (306 tests); visually verified against both demo plans via the run-improve-app skill. Untested-in-anger corners (noted in child beans): non-fixed target variants, adjusted-target provenance, time-off windows, and diagnostics rendering — demo data never produces them; they'll be exercised by the first real marathon-style plan or malformed authored content.
