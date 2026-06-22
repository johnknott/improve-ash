---
# improve-ash-xz1b
title: Validate live event commands against event type contracts
status: completed
type: feature
priority: high
created_at: 2026-06-22T23:18:00Z
updated_at: 2026-06-22T23:21:40Z
parent: improve-ash-fx46
---

Runtime generic event logging should validate required item link roles, unsupported roles, and basic payload requirements from the authored EventType before persistence/effect generation.

Todo:
- [x] Add runtime event contract validator for required/unknown item link roles.
- [x] Add basic runtime payload required-field validation.
- [x] Run validation before creating EventInstance/links/effects.
- [x] Add focused tests and run verification.

Summary:
- Added `Improve.Journal.EventContract` so live generic event writes enforce authored required item-link roles, unsupported roles, and required payload fields before persistence/effect generation.
- Shared `PathReader` now safely handles missing atom-form keys, keeping diagnostics/effect interpretation aligned for nested paths.
- Preserved idempotent duplicate handling and explicit forbidden behavior for dose wrapper ownership boundaries.
- Verification: `mise run verify` passed with 88 tests and TypeScript checking.
