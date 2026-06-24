---
# improve-ash-82lt
title: Define backend-only verification for story/model pass
status: todo
type: task
priority: normal
tags:
    - backend
    - tests
created_at: 2026-06-24T12:17:13Z
updated_at: 2026-06-24T12:17:13Z
parent: improve-ash-qtdm
---

## Context

While the UI is paused, backend story/model work needs a clear verification command set that does not accidentally expand scope into frontend implementation.

## Tasks

- [ ] Document the backend-only checks for this pass.
- [ ] Ensure ExUnit, formatting, compile warnings, AshTypescript generation/checks, and story scripts are covered.
- [ ] Decide whether full `mise run verify` remains the handoff command or whether a backend-focused task should be added.
- [ ] Update README/notes if the workflow changes.

## Acceptance

- [ ] A backend-only story/model change has a clear pre-handoff verification path.
