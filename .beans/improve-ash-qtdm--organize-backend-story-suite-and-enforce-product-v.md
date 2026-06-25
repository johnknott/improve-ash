---
# improve-ash-qtdm
title: Organize backend story suite and enforce product vocabulary
status: completed
type: epic
priority: normal
tags:
    - backend
    - stories
created_at: 2026-06-24T12:16:47Z
updated_at: 2026-06-24T13:19:58Z
parent: improve-ash-qdoa
---

## Context

The story suite is the backend rehearsal for the future UI. It should be easy to run, ordered around product questions, and protected against regression into storage/internal vocabulary.

## Acceptance

- [x] Story scripts are renamed/reorganized around the recommended story set.
- [x] Story output defaults to product language and hides internal terms.
- [x] Tests catch regressions such as removed goal terms, raw payload paths, or domain-specific core verbs in simple stories.
- [x] Backend verification commands are documented for this story/model pass.
