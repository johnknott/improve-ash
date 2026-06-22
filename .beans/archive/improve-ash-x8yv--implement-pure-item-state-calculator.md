---
# improve-ash-x8yv
title: Implement pure item state calculator
status: completed
type: task
priority: high
tags:
    - planning
    - state
created_at: 2026-06-22T19:52:03Z
updated_at: 2026-06-22T20:31:23Z
parent: improve-ash-n3bi
---

## Plan

- [x] Re-read ItemState requirements from the spike spec.
- [x] Add a pure Improve.Planning.ItemState module with explicit inputs and outputs.
- [x] Support active add/subtract/set quantity effects and ignore voided effects.
- [x] Return starting facts, active effects, calculated state, and plain-English warnings.
- [x] Add focused pure unit tests, including vial quantity and replacement/void behavior.
- [x] Run verification and close the bean.

## Completed

- Added Improve.Planning.ItemState as a database-free deterministic calculator.
- Supports add_quantity, subtract_quantity, set_quantity, correction, and set_fact effects.
- Ignores voided effects and preserves active effects in the result.
- Returns starting facts, calculated state, active effects, and warnings.
- Adds warnings for missing starting quantity, missing effect quantity, unsupported effects, unit mismatch, low quantity, and insufficient future quantity.
- Added pure unit tests for vial-style quantity derivation, replacement/void behavior, set/correction behavior, set_fact merging, and warnings.
- Verified with mise run verify.
