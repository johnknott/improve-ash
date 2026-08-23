---
# improve-ash-o39y
title: 'UX milestone: friendly logging and a calmer Today'
status: completed
type: epic
priority: normal
created_at: 2026-07-05T11:39:29Z
updated_at: 2026-08-23T12:15:26Z
---

Make Phase 1-2 surfaces friendly before Phase 3, guided by the old app's best patterns (target card with guidance, What happened? choice, read-only unit chip, note behind disclosure, dynamic submit labels, check-in wizard). Decisions from John: track skips get modeled in the journal now; the raw 'Why today looks like this' projector block is removed once cards speak product language; sessions are steps inside the check-in wizard. Units are predefined by the track and never free-typed in track flows.

## Completion Note

All eight child Beans are complete. The milestone now covers journal-backed track skips, friendly track and generic logging, the check-in wizard, calmer diagnostics and card explanations, realistic imported test data, and the final Today layout/count pass. The closing `mise run verify` passed with 309 tests plus story, contract, frontend-check, and production-build verification.
