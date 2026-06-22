---
# improve-ash-lomt
title: Expose read only AshAI tools and smoke tests
status: completed
type: task
priority: normal
tags:
    - ai
    - tools
created_at: 2026-06-22T19:52:29Z
updated_at: 2026-06-22T21:14:47Z
parent: improve-ash-fc2p
---

- [x] Read installed AshAI 0.7.2 docs before changing tool DSL.
- [x] Add tiny read-only generic Ash actions for projection, plan summary, recent journal events, and item state.
- [x] Expose those actions as AshAI tools.
- [x] Add smoke tests that execute tools through AshAI without calling an LLM.
- [x] Run verification and close the bean.

## Result

Added `Improve.Ai` with AshAI tool exposure and `Improve.Ai.ReadTool` as a stateless Ash resource with generic read-only actions for:

- `project_today`
- `get_plan_summary`
- `get_recent_journal_events`
- `get_item_state`

The actions delegate to existing `Plans` and `Journal` APIs with the supplied actor, so they reuse normal domain behavior and policies rather than bypassing them. Results are returned as JSON-compatible maps for tool use.

Added `test/improve/ai/read_tool_test.exs` to discover exposed tools through AshAI, execute projection/summary/journal/state tools, and prove another actor cannot read an owned item through the tool layer.

Verification:

- `mix test test/improve/ai/read_tool_test.exs`
- `mise run verify`
- `mix ash_postgres.generate_migrations --check`
