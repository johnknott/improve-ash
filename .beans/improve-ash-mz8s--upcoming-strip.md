---
# improve-ash-mz8s
title: Upcoming strip
status: completed
type: task
priority: normal
created_at: 2026-07-04T22:29:09Z
updated_at: 2026-07-04T22:48:41Z
parent: improve-ash-0m50
blocked_by:
    - improve-ash-hmnn
---

Compact preview of today.upcoming under the day's work: per-day groups with work item titles and statuses, reusing the same status vocabulary at smaller scale. The dashboard payload already carries upcoming days — render, don't refetch.

## Summary of Changes

UpcomingStrip.svelte groups today.upcoming by plannedFor into a horizontal strip of day cards (formatDate labels, item titles). Verified visually: gym plan shows "Mon 6 Jul — Upper-biased gym visit" on the rest day and "Wed 8 Jul" from the work day.
