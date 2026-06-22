---
# improve-ash-9pfh
title: Headless product kernel V2
status: completed
type: milestone
priority: high
created_at: 2026-06-22T21:37:02Z
updated_at: 2026-06-22T23:03:48Z
---

Next phase after the headless Ash POC. Focus on the product-kernel model and workflows from notes/full-rewrite-spec.md while explicitly deferring auth, billing, profile, admin, and UI.\n\nScope:\n- deterministic projection beyond the gym happy path\n- direct goals as first-class scheduled work\n- generic event logging and effect interpretation\n- same-plan integrity and safer command boundaries\n- plan draft portability and richer diagnostics\n- offline/idempotent journal ingress design and minimal server shape\n\nOut of scope for this milestone:\n- React or LiveView UI\n- authentication/session product work\n- billing and entitlements\n- profile/account settings\n- admin/operations surfaces

\n\nCompleted: all V2 child epics are done: projection/scheduling V2, generic journal/effects, plan draft import/export/diagnostics, offline/idempotent journal ingress, and plan integrity/command hardening. Verification: latest mise run verify passes with 83 tests.
