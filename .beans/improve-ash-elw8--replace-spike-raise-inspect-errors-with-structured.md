---
# improve-ash-elw8
title: Replace spike raise inspect errors with structured command errors
status: completed
type: task
priority: normal
created_at: 2026-06-22T21:38:29Z
updated_at: 2026-06-22T23:01:45Z
parent: improve-ash-dcal
---

Replace rough raise inspect(error) paths in command workflows with structured return errors or domain exceptions that preserve useful Ash detail. Acceptance: callers/tests can assert error categories without string soup.

\n\nCompleted: added Improve.CommandError with stable category/operation/details/cause fields, replaced spike-style raise inspect paths in command workflows and demo installers, and updated tests to assert structured invalid_command and forbidden categories. Verification: mise run verify passes with 83 tests.
