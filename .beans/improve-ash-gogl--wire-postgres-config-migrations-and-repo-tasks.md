---
# improve-ash-gogl
title: Wire Postgres config migrations and repo tasks
status: completed
type: task
priority: high
tags:
    - database
    - devex
created_at: 2026-06-22T19:51:55Z
updated_at: 2026-06-22T20:05:51Z
parent: improve-ash-08ww
---

## Plan

- [x] Verify local Postgres startup through mise.
- [x] Verify create/migrate/seed task behavior against the Phoenix app; review reset wrapper without running the destructive reset.
- [x] Tighten mise tasks if any command assumes missing setup or skips DB bootstrap.
- [x] Run the local verification command after any task changes.

## Summary of Changes

Updated DB-backed mise tasks so test, db:create, db:migrate, db:reset, and db:seed all start local Postgres before invoking Mix.

Cleaned up stale task descriptions now that the Phoenix app is scaffolded.

Verified non-destructive commands: mise run db:up, mise run db:create, mise run db:migrate, and mise run db:seed. The db:reset wrapper was reviewed but not run because it drops local data.

Verification: mise run verify passes with 2 generated tests.
