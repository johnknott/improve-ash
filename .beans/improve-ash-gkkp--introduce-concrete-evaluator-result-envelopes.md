---
# improve-ash-gkkp
title: Introduce concrete evaluator result envelopes
status: completed
type: task
priority: normal
created_at: 2026-06-24T20:38:31Z
updated_at: 2026-06-24T20:51:50Z
parent: improve-ash-z91i
blocked_by:
    - improve-ash-8qr7
---

Replace loose map-shaped results with small internal structs or clearly documented typed envelopes once two evaluator kinds reveal the real common shape.

Keep diagnostics explicit and always present where the caller expects them.

Done when the contract has enough structure to be readable without pretending to be a public plugin API.

## Summary of Changes

Hardened evaluator result shapes with explicit internal types and specs rather than introducing a shared result struct.

Decision:
- Schedule evaluators return a typed `{:ok, due?, diagnostics}` result, with dispatcher errors remaining explicit.
- Target diagnostic evaluators return a typed diagnostics list.
- The shared convention is explicit input plus explicit diagnostics, but the answer shape differs by evaluator kind. A generic result struct would add weight and hide that difference right now.

This gives the contract enough structure for the second evaluator pass while keeping it internal and pre-public-API. Verified with `mix compile --warnings-as-errors`.
