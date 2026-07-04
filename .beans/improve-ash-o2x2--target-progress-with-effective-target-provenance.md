---
# improve-ash-o2x2
title: Target progress with effective-target provenance
status: completed
type: feature
priority: normal
created_at: 2026-07-04T22:28:51Z
updated_at: 2026-07-04T22:48:41Z
parent: improve-ash-0m50
blocked_by:
    - improve-ash-hmnn
---

Render the seven TargetProgress variants from the Phase 0 union on track cards: fixed (linked events), metric (recorded value + unit), checklist ('2 of 3 complete', item chips), period_total ('12 of 20 km this week'), progression (expected today, from→to), responsive progression (step position, deload), adaptive (fields recorded). Narrow by distinctive keys — there is no discriminant field.

Provenance from day one (the roadmap's Phase 1 gate): the work payload carries provenance: {planned, effective, adjusted, source, reason} | null (built in ui_api.ex provenance_json/1, bean improve-ash-eeou). First type it in frontend/src/api/types.ts — it was missed in the Phase 0 sweep — then render adjusted targets distinctly: effective value shown as the target, with the authored value and plain-language reason ('lowered while ill') in a quiet affordance.

## Summary of Changes

TargetProgressView.svelte narrows the 7-variant union by distinctive keys and renders the backend label as the progress line, with checklist chips (done/pending) for checklist targets. Typed `TargetProvenance` + `WorkItem.provenance` (the field ui_api emits but Phase 0 missed) and rendered adjusted targets as an "Adjusted" badge + reason + planned-value summary. Note: demo plans carry no adjusted targets or non-fixed tracks, so the variant rendering is verified by types + the label contract, not visually — first marathon-style plan will exercise it.
