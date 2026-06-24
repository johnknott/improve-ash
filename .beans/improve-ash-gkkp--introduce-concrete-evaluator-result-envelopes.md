---
# improve-ash-gkkp
title: Introduce concrete evaluator result envelopes
status: draft
type: task
priority: normal
created_at: 2026-06-24T20:38:31Z
updated_at: 2026-06-24T20:38:31Z
parent: improve-ash-z91i
blocked_by:
    - improve-ash-8qr7
---

Replace loose map-shaped results with small internal structs or clearly documented typed envelopes once two evaluator kinds reveal the real common shape.

Keep diagnostics explicit and always present where the caller expects them.

Done when the contract has enough structure to be readable without pretending to be a public plugin API.
