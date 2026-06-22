---
# improve-ash-usmw
title: Scaffold Phoenix Ash app with latest stable dependencies
status: completed
type: task
priority: high
tags:
    - scaffold
    - dependencies
created_at: 2026-06-22T19:51:55Z
updated_at: 2026-06-22T20:02:17Z
parent: improve-ash-08ww
---

## Plan

- [x] Check current official package versions and docs before choosing dependency versions.
- [x] Scaffold a minimal headless Phoenix app in this existing repo.
- [x] Add Ash/AshPostgres and required baseline dependencies.
- [x] Keep UI assets out of scope.
- [x] Get the initial test suite passing.

## Summary of Changes

Scaffolded a minimal Phoenix 1.8.8 app in the existing repository using headless flags: no HTML, no assets, no dashboard, no mailer, no gettext, binary IDs, and no generated AGENTS.md.

Added current stable baseline dependencies from Hex: Ash 3.29.1, AshPostgres 2.10.0, AshTypescript 0.17.3, AshAI 0.7.2, PhoenixEcto 4.7.0, EctoSQL 3.14.0, and Postgrex 0.22.2.

Configured development and test database settings for the local improve-ash Postgres container on port 5433.

Verification: mise run verify passes with 2 generated tests.
