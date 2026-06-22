---
# improve-ash-v06a
title: Make weekly quota projection more today-aware
status: completed
type: feature
priority: normal
created_at: 2026-06-22T23:18:00Z
updated_at: 2026-06-22T23:18:00Z
parent: improve-ash-fx46
---

Improve times_per_week placement so missed earlier-week slots can flow forward to later valid days based on as_of_date, while preserving deterministic explainable output.

Todo:
- [x] Place remaining weekly quota from `as_of_date` forward when projecting another date.
- [x] Preserve existing single-date weekly quota behavior.
- [x] Add focused regression coverage for missed quota flowing to Friday.
- [x] Run full verification.

Summary:
- Weekly quota placement now keeps the established single-date behavior, but when projecting a date from a different `as_of_date`, remaining quota is placed from that as-of date forward.
- Added regression coverage showing missed Monday quota can flow forward to Wednesday and Friday in the same week.
- Verification: `mise run verify` passed with 91 tests and TypeScript checking.
