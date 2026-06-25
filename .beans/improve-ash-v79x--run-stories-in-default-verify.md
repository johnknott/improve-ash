---
# improve-ash-v79x
title: Run stories in default verify
status: completed
type: task
priority: normal
created_at: 2026-06-25T09:56:05Z
updated_at: 2026-06-25T10:44:36Z
parent: improve-ash-6lsw
---

Update .mise.toml so mise run verify includes the executable product stories, not only verify:backend. Done when the default handoff command catches story regressions while still running frontend checks/build.

- Summary of Changes: Updated default `mise run verify` to run executable product stories in addition to format, lint, ExUnit, codegen/type checks, and frontend check/build. Verified by running full `mise run verify` successfully.
