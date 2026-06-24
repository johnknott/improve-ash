---
# improve-ash-qtdm
title: Organize backend story suite and enforce product vocabulary
status: todo
type: epic
priority: normal
tags:
    - backend
    - stories
created_at: 2026-06-24T12:16:47Z
updated_at: 2026-06-24T12:16:47Z
parent: improve-ash-qdoa
---

## Context

The story suite is the backend rehearsal for the future UI. It should be easy to run, ordered around product questions, and protected against regression into storage/internal vocabulary.

## Acceptance

- [ ] Story scripts are renamed/reorganized around the recommended story set.
- [ ] Story output defaults to product language and hides internal terms.
- [ ] Tests catch regressions such as `direct_goal`, raw payload paths, or domain-specific core verbs in simple stories.
- [ ] Backend verification commands are documented for this story/model pass.
