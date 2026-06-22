---
# improve-ash-9pfh
title: Headless product kernel V2
status: todo
type: milestone
priority: high
created_at: 2026-06-22T21:37:02Z
updated_at: 2026-06-22T21:37:02Z
---

Next phase after the headless Ash POC. Focus on the product-kernel model and workflows from notes/full-rewrite-spec.md while explicitly deferring auth, billing, profile, admin, and UI.\n\nScope:\n- deterministic projection beyond the gym happy path\n- direct goals as first-class scheduled work\n- generic event logging and effect interpretation\n- same-plan integrity and safer command boundaries\n- plan draft portability and richer diagnostics\n- offline/idempotent journal ingress design and minimal server shape\n\nOut of scope for this milestone:\n- React or LiveView UI\n- authentication/session product work\n- billing and entitlements\n- profile/account settings\n- admin/operations surfaces
