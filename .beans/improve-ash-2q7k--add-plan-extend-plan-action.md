---
# improve-ash-2q7k
title: Add Plan extend_plan action
status: completed
type: feature
priority: high
created_at: 2026-06-25T09:55:47Z
updated_at: 2026-06-25T10:52:45Z
parent: improve-ash-qz52
---

Add a named plan update action that extends ends_on by a positive number of weeks. Keep it Ash-visible and policy-protected, validate the argument, and cover ownership plus date math in tests. This is the first concrete durable proposal action for V1.

- Summary of Changes: Added an Ash-visible Plan extend_plan update action with a positive weeks argument, exposed it through Improve.Plans, and covered date math, invalid weeks, and ownership in tests. Added App.apply_proposal/3 and apply_proposal!/3 to apply approved extend_plan proposal maps while returning clear unsupported-action diagnostics. Updated the review story to show an approved extend_plan proposal being applied. Verified with focused tests/story runs and full `mise run verify`.
