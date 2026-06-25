---
# improve-ash-igl6
title: Rewrite gym session story as generic session-from-pools story
status: completed
type: task
priority: normal
tags:
    - backend
    - stories
created_at: 2026-06-24T12:16:12Z
updated_at: 2026-06-24T12:55:24Z
parent: improve-ash-xqim
blocked_by:
    - improve-ash-c1xd
---

## Context

The old gym story should become a generic proof of sessions, pools, recommendations, swaps, and actual results. Gym can remain fixture content, but not core API vocabulary.

## Tasks

- [x] Create or rewrite a story like `04_session_from_pools.exs`.
- [x] Show projected recommendations and actual logged results in plain English.
- [x] Preserve recommendation-versus-swap in the story output.
- [x] Update story specs to assert the persisted recommendation and actual values.

## Acceptance

- [x] The story proves the session pattern without requiring exercise/machine-specific helper calls.
