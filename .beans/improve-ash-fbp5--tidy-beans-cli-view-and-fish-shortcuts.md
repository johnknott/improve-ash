---
# improve-ash-fbp5
title: Tidy Beans CLI view and fish shortcuts
status: completed
type: task
priority: normal
created_at: 2026-06-25T10:07:09Z
updated_at: 2026-06-25T10:08:44Z
---

Normalize stale Beans statuses so ready lists stop showing closed work, and add Fish shortcuts for the common active-bean views.

## Summary of Changes

- Normalized old closed Beans from `done`/`complete` to the configured `completed` status so they no longer show as unknown or ready.
- Added Fish functions: `br` for a compact actionable ready list, `ba` for the ready tree, and `bs` for showing bean details.
- Verified `beans check`, `beans ls --ready`, and the new Fish functions.
