---
# improve-ash-6lsw
title: Harden V1 backend handoff confidence
status: completed
type: epic
priority: normal
created_at: 2026-06-25T09:54:17Z
updated_at: 2026-06-25T10:48:14Z
parent: improve-ash-8e5j
---

Small, high-trust cleanup before calling the backend V1-shaped: default verification should run stories, Phoenix app endpoints need negative tests, stale Track naming should be swept, and old spike/POC wording should be refreshed where it reaches active code/docs.

- Summary of Changes: Default verification now runs stories, active V1 naming/spike wording has been swept, and Phoenix app-controller negative tests cover unauthenticated, cross-user, and malformed payload paths. Full `mise run verify` is green.
