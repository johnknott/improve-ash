---
# improve-ash-843h
title: Fix dayLabel ignoring selected dashboard date
status: completed
type: bug
created_at: 2026-07-04T13:27:08Z
updated_at: 2026-07-04T13:27:08Z
parent: improve-ash-fd57
---

plan_json computed elapsed days from Date.utc_today() instead of the dashboard's selected date, so day labels lied for any past/future date and made app_controller_test date-dependent. Threaded the resolved dashboard date through plan_json. Found while working improve-ash-gghs.
