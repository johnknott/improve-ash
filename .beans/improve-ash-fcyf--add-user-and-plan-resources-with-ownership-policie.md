---
# improve-ash-fcyf
title: Add user and plan resources with ownership policies
status: completed
type: task
priority: high
tags:
    - ash
    - ownership
created_at: 2026-06-22T19:52:03Z
updated_at: 2026-06-22T20:15:49Z
parent: improve-ash-n3bi
---

## Plan

- [x] Check current official Ash/AshPostgres docs for resources, domains, policies, and migrations.
- [x] Add User and Plan Ash resources with UUID primary keys and Postgres persistence.
- [x] Add Accounts and Plans domains with product-oriented code interfaces.
- [x] Generate/apply migrations for users and plans.
- [x] Add focused tests for user/plan creation and owner-scoped plan reads.
- [x] Run local verification.

## Completed

- Added Accounts/User and Plans/Plan Ash resources backed by AshPostgres.
- Registered Ash domains in app config and converted the repo to AshPostgres.Repo.
- Added picosat_elixir for Ash.Policy.Authorizer.
- Generated and applied users/plans migrations plus Ash resource snapshots.
- Added DB-backed tests for plan creation, actor ownership filtering, and cross-user isolation.
- Verified with mise run verify.
