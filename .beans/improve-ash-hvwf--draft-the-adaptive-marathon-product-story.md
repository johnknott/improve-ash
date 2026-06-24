---
# improve-ash-hvwf
title: Draft the adaptive marathon product story
status: completed
type: task
priority: normal
created_at: 2026-06-24T20:38:44Z
updated_at: 2026-06-24T21:48:35Z
parent: improve-ash-97ij
---

Write the product-facing story for an adaptive marathon plan before implementing it.

The story should cover baseline input, race date, plan structure, missed work, illness/injury/holiday adaptation, and review language.

Done when the story reads like a product flow rather than a framework demo.

## Ready

Ready as the next backend-only step after the schedule and target evaluator probes. Start with a product-facing story, not implementation. The story should clarify what can be declarative, what needs one-time customization, what is derived adaptation, and what would require committed plan edits.



## Completed

Story 10 now captures the adaptive marathon product flow. The runnable layer proves the declarative marathon plan shape today: four scheduled run tracks, weekday projection, run-completed shoe wear via item effects, low-quantity warning, journal, and review. The intended layers document baseline-derived customization plus missed-session, illness, injury, and holiday adaptation as downstream evaluator work.

Verification:
- MIX_ENV=test mix run priv/scripts/stories/10_adaptive_marathon.exs
- mix test test/improve/stories/vocabulary_test.exs test/improve/stories/stories_test.exs
- mise run fmt
- mise run lint
- mise run test
- mix ash_typescript.codegen --check
- mise run typescript:check
- mise run stories:run
