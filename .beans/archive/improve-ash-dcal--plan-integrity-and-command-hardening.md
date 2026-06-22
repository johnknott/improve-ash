---
# improve-ash-dcal
title: Plan integrity and command hardening
status: completed
type: epic
priority: high
created_at: 2026-06-22T21:37:18Z
updated_at: 2026-06-22T23:03:47Z
parent: improve-ash-9pfh
---

Harden the model before broader write APIs. Ensure foreign IDs crossing resource boundaries belong to the same plan, replace rough spike error patterns with structured errors where useful, and evaluate Ash command/action boundaries for multi-step workflows.\n\nOut of scope: public auth/session product work.

\n\nCompleted: all child Beans are done. The model has same-plan validation coverage, audited foreign-key surfaces, structured command errors, and a current-docs evaluation of Ash generic actions. Verification: latest mise run verify passes with 83 tests.
