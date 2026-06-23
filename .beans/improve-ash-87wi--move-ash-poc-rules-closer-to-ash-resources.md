---
# improve-ash-87wi
title: Move Ash POC rules closer to Ash resources
status: completed
type: task
priority: normal
created_at: 2026-06-23T14:07:28Z
updated_at: 2026-06-23T14:13:04Z
---

Implement practical follow-ups from the Ash philosophy review.\n\n- [x] Add Ash-declared plan summary aggregates and use them from summarize_plan\n- [x] Add declarative transition/state validations for session, slot, event, and effect resources\n- [x] Harden journal/session command paths against stale state and duplicate races without widening scope\n- [x] Improve Ash relationship/load usage for read assembly where practical\n- [x] Add AGENTS guidance to keep building the Ash way\n- [x] Run focused tests and verification

## Summary of Changes\n\nMoved plan summary counts into Ash aggregates, replaced manual projection/read assembly with Ash relationship loads where practical, added action-level transition guards for session, slot, event, and effect state changes, hardened idempotent journal logging against duplicate races, added regression coverage for terminal state rewrites, and updated AGENTS.md with explicit Ash-way guidance. Verification passed with mise run verify and ash_postgres migration check.
