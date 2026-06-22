---
# improve-ash-avt7
title: Implement quota scheduling semantics
status: completed
type: feature
priority: high
created_at: 2026-06-22T21:37:54Z
updated_at: 2026-06-22T22:25:12Z
parent: improve-ash-lde6
---

Replace the current times_per_week-as-weekdays shortcut with explicit quota placement. Acceptance: schedules can place N occurrences within a week using allowed weekdays, date range, minimum gaps, and completed history where relevant.



Completed:
- Replaced times_per_week-as-allowed-weekday behavior with deterministic weekly quota placement.
- Quota placement respects times/count, allowed_weekdays, schedule date range, and minimum_gap_days.
- Completed history now feeds quota placement: direct goals use active linked journal events; sessions use completed session occurrences.
- Plans.project_today/2 passes session occurrences into projection input.
- Added tests proving the gym Saturday allowed day is not projected after the weekly quota is placed, and direct goal completed history affects remaining weekly placement.
- mise run verify passes.
