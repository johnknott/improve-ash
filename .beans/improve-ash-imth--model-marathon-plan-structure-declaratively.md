---
# improve-ash-imth
title: Model marathon plan structure declaratively
status: completed
type: task
priority: normal
created_at: 2026-06-24T20:38:44Z
updated_at: 2026-06-25T03:55:00Z
parent: improve-ash-97ij
blocked_by:
    - improve-ash-z91i
---

Represent marathon plan structure using normal plans, tracks, sessions, slots, schedules, items, and pools before adding custom evaluator logic.

Done when the static structure proves what the core can already express without authored code.

## Summary of Changes

The adaptive marathon story now models the static plan structure declaratively
with ordinary Improve primitives: a dated plan, four scheduled run tracks
(`long_run`, `tempo_run`, `intervals`, and `easy_run`), a shared `run_completed`
event type, stateful race shoes, item effects for shoe wear, journal history,
review output, and plan-scoped time off.

The runnable story proves the core model can hold the marathon plan before
customization or adaptation logic runs. Verification is covered by
`priv/scripts/stories/10_adaptive_marathon.exs` and `mise run verify:backend`.
