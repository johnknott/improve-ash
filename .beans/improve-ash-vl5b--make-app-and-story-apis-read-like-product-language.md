---
# improve-ash-vl5b
title: Make App and Story APIs read like product language
status: completed
type: epic
priority: high
tags:
    - backend
    - story-api
created_at: 2026-06-24T12:15:14Z
updated_at: 2026-06-24T12:36:30Z
parent: improve-ash-qdoa
---

## Context

The future UI should be sketchable directly from executable stories. `Improve.App` should expose real product operations, while `Improve.Stories` stays a thin readability layer with actor/reset/printing conveniences.

## Acceptance

- [x] Simple stories use plan/track/session/item/pool/event/effect vocabulary.
- [x] Simple stories do not require raw event schemas or payload paths in the happy path.
- [x] Helpers that represent real UI operations live in `Improve.App`, not only `Improve.Stories`.
- [x] Story diagnostics and output are plain English.

## Summary of Changes

Completed the product-language App/Story API pass for simple tracks: target and record constructors, schedule constructors and diagnostics, inferred simple event types, rewritten reading story, target-types story, and story specs. Verified through ExUnit, story runs, contract/codegen checks, and old vocabulary searches.
