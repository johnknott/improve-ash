---
# improve-ash-vc69
title: Remove demo-specific vocabulary from runtime code
status: completed
type: task
created_at: 2026-06-23T18:39:51Z
updated_at: 2026-06-23T18:39:51Z
---

Find and remove hardcoded gym/vial/peptide/demo-story vocabulary from runtime code while leaving fixtures and tests alone.

- [x] Inventory hardcoded scenario terms outside fixtures/tests/stories
- [x] Refactor backend runtime APIs/messages/helpers toward generic event/item language
- [x] Refactor frontend runtime labels where practical
- [x] Keep demo fixture behavior intact
- [x] Run verification

Notes:

- Backend runtime APIs now use generic linked-item event language instead of dose/vial helpers.
- Fixture-specific registry keys remain isolated behind `Improve.Fixtures.DemoPlans`.
- Remaining frontend grep hits are intentional demo fixture keys used by the demo-plan installer.
- Verified with `mix test`, `npm run check` in `frontend/`, and `npm run build` in `frontend/`.
