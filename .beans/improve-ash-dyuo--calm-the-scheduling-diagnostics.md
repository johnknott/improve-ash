---
# improve-ash-dyuo
title: Calm the scheduling diagnostics
status: completed
type: feature
priority: normal
created_at: 2026-07-05T11:39:29Z
updated_at: 2026-07-05T12:01:43Z
parent: improve-ash-o39y
---

Backend: schedule diagnostics carry the owner's name, and the partial-first-week case (schedule starts/ends mid-week truncating candidates) is severity :info with calm copy ('General Fitness starts this week - 1 session fits before Monday'); genuine constraint conflicts stay :warning. Frontend: non-error diagnostics collapse into a quiet '1 scheduling note' pill above the work list, expandable, with the Review plan setup link inside the expansion; errors stay loud.

## Summary of Changes
TimesPerWeek diagnostics now classify structurally (weekday-only full-week placement capacity vs the range-filtered reality): rules that could never fit the quota warn as :unsatisfiable_schedule_rules ("X asks for 3× a week, but its allowed weekdays and minimum gap only fit 1. Adjust its schedule."); everything situational (plan starting mid-week, days already gone) is :info :partial_week_schedule ("X: 1 of 3 this week — the rest don't fit in the days left."). Owner names flow in via input.schedule_owner_name set by the projector at both call sites. Frontend: error-severity diagnostics stay loud; warnings/info collapse into a "1 scheduling note" pill (details/summary) with Review plan setup inside the expansion. Verified visually on the demo plan's partial first week.
