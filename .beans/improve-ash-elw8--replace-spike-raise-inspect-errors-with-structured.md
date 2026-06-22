---
# improve-ash-elw8
title: Replace spike raise inspect errors with structured command errors
status: todo
type: task
priority: normal
created_at: 2026-06-22T21:38:29Z
updated_at: 2026-06-22T21:38:29Z
parent: improve-ash-dcal
---

Replace rough raise inspect(error) paths in command workflows with structured return errors or domain exceptions that preserve useful Ash detail. Acceptance: callers/tests can assert error categories without string soup.
