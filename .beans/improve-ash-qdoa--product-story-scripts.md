---
# improve-ash-qdoa
title: Product story scripts
status: completed
type: milestone
priority: normal
created_at: 2026-06-23T06:57:39Z
updated_at: 2026-06-24T13:19:58Z
---

Add executable plain-English product story scripts that pressure the app-facing API while calling the same headless domains the UI will use.

Progress:
- Track model replacement completed in `improve-ash-qvk7`: the backend no longer uses the old goal resource/API shape.
- Product-language facade completed in `improve-ash-vl5b`: plan, track, schedule, session, item, journal, and AI-context operations read through `Improve.App`.
- Generic session and recommendation stories completed in `improve-ash-xqim`: pooled sessions preserve recommendation snapshots, actual results, skips, swaps, and adaptive item suggestions.
- Stateful item, correction, and offline stories completed in `improve-ash-7on2`: item state derives from starting facts plus active item effects, corrections preserve journal history, and offline ingress returns product-facing outcomes.
- Stable client references completed in `improve-ash-jd16`: offline commands can be built from app-facing keys and idempotency metadata.
- Story suite and vocabulary enforcement completed in `improve-ash-qtdm`: numbered backend stories now match the product question set, review is deterministic/read-only, regressions are tested, and backend-only verification is documented.
