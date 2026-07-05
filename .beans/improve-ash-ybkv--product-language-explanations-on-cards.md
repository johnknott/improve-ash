---
# improve-ash-ybkv
title: Product-language explanations on cards
status: completed
type: task
priority: normal
created_at: 2026-07-05T11:39:29Z
updated_at: 2026-07-05T12:01:43Z
parent: improve-ash-o39y
---

Rewrite projector explanation templates from engine traces ('Projected X as started from its session occurrence') to user language built from schedule cadence and state ('Every Mon, Wed, Fri or Sat - 3x a week', 'Started - 2 of 5 slots logged'). Remove the Why-today-looks-like-this block from TodayPage (data stays in the payload). Story/test expectations updated.

## Summary of Changes
New Schedules.describe/1 renders cadence in product language ("Every day", "3× a week", "Every Mon and Wed", "Every 2 weeks", "Monthly on day 15"). Projector explanation templates rewritten: track planned → cadence, completed → "Done for today.", missed → "Missed — no entry for this day.", on_hold → "On hold — {reason or key}."; sessions planned → cadence, started/partial/completed carry the progress label ("In progress — 2 of 5 logged."), skipped/missed in plain words. Recommender reasons humanized too ("The plan's usual starting point.", "Based on your last Push entry.", "A starting suggestion — adjust as you go.", "Picked from the Push pool, favouring variety."). The raw "Why today looks like this" block is gone from TodayPage (payload still carries explanations). Verified visually: card line reads "3× a week", slot notes read the new copy. 309 tests green with updated assertions.
