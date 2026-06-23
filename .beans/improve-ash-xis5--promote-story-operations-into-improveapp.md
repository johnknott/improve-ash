---
# improve-ash-xis5
title: Promote Story operations into Improve.App
status: completed
type: task
priority: normal
created_at: 2026-06-23T08:58:51Z
updated_at: 2026-06-23T09:07:10Z
parent: improve-ash-qdoa
---

Promote the stable product-facing operations discovered by the story scripts into
Improve.App and small app modules, leaving reset/demo/printing concerns in
Improve.Stories.

- [x] Extract authoring, schedule/session/effect builders, logging, state, and AI context app modules
- [x] Make Improve.App a clear facade over those modules
- [x] Update Improve.Stories to delegate product operations to Improve.App
- [x] Add or update tests for the promoted API and story compatibility
- [x] Run story scripts and full verification

## Summary of Changes

Promoted the stable story-discovered product operations into the Improve.App
facade backed by focused app modules for authoring, logging, projection, state
reads, AI context, and small constructors.

Improve.Stories now delegates product work to Improve.App while retaining story
reset, demo-user, and printing concerns. Added App-level tests for
authoring/direct-goal logging, default direct-goal links, and session slot
defaults. Ran all seven story scripts and `mise run verify`; verification passes
with 101 tests.
