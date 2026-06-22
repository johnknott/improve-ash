---
# improve-ash-vlwo
title: Test cross user ownership boundaries
status: completed
type: task
priority: high
tags:
    - ownership
    - tests
created_at: 2026-06-22T19:52:29Z
updated_at: 2026-06-22T21:05:51Z
parent: improve-ash-fc2p
---

- [x] Re-read existing ownership/policy tests so this complements rather than duplicates them.
- [x] Add a cross-user scenario around the real gym/vial workflows and public domain APIs.
- [x] Prove unrelated actors cannot read, project, start, log, correct, or derive state from another user plan.
- [x] Run verification and close the bean.

## Result

Added a high-level cross-user ownership scenario around the public workflow helpers. It proves an unrelated actor cannot summarize/project another user plan from a struct, start someone else’s projected session, read another plan’s journal, derive another item’s state, log another plan’s dose event, or correct another user’s event.

Tightened helper boundaries so `Plans.summarize_plan/2`, `Plans.project_today/2`, `Journal.read_journal/2`, and `Journal.get_item_state/2` re-authorize parent records through Ash for the current actor before doing helper work.

Verification:

- `mix test test/improve/ownership_boundary_test.exs`
- `mise run verify`
- `mix ash_postgres.generate_migrations --check`
