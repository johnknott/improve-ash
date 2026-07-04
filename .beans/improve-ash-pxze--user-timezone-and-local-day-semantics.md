---
# improve-ash-pxze
title: User timezone and local-day semantics
status: completed
type: bug
priority: normal
created_at: 2026-07-04T13:20:04Z
updated_at: 2026-07-04T19:06:37Z
parent: improve-ash-fd57
---

Add timezone to User, convert effective_at to local date in all six target evaluators, Review, RecentLoad; fix the 20:00-UTC date-only default in Value.default_datetime. (notes/fable-todo.md item #3)

## Summary of Changes

- `tz` library (not tzdata — its hackney dependency conflicts with the lock)
  as the Elixir time zone database.
- `User.timezone` attribute (default `Etc/UTC`), validated by new
  `Improve.Validations.ValidTimezone` (with `atomic/3` for Ash 3 atomic
  updates), settable via `/api/auth/profile`, returned in `user_json`.
  Migration `add_user_timezone`.
- New pure-core helper `Improve.Planning.LocalDate` — UTC timestamp → the
  user's local calendar date, falling back to UTC on unknown zones.
- Timezone threaded through: projection input (from the plan owner, loaded
  with the plan), the `Evaluation` struct, all six target evaluators,
  `TimesPerWeek.completed_dates`, `Review`, and `RecentLoad` (whose
  descriptor now requires `:timezone`; stories provide it).
- `Value.default_datetime/2`: date-only logging now means 20:00 in the
  user's zone, converted to UTC for storage (DST gap/ambiguity handled).
- Tests: end-to-end local-day bucketing (21:30 New York event lands on the
  local day, not the UTC day), `default_datetime` unit tests, profile
  endpoint accepts valid zones and 422s invalid ones.

Note: no data migration — existing users default to `Etc/UTC`, so behaviour
is unchanged until a user sets a real time zone. Frontend/mobile should send
the device zone at profile completion.
