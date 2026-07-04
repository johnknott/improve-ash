---
# improve-ash-3faz
title: Unify the TS contract and casing
status: completed
type: task
priority: normal
created_at: 2026-07-04T13:20:04Z
updated_at: 2026-07-04T19:27:25Z
parent: improve-ash-fd57
---

One casing convention end-to-end, frontend consumes generated types, codegen drift-check in precommit. (notes/fable-todo.md item #8)

## Summary of Changes

- **Casing rule, now encoded in `UiApi.camelize_keys/1`**: every key the
  backend generates is camelCase; user-authored JSONB (facts, payloads,
  rules, schemas) passes through untouched. Applied to the previously
  snake_case leaks: `targetProgress`, `session.state`, plan `summary`,
  projection `diagnostics`/`explanations`, and item-state `warnings`.
  Request params remain snake_case (unchanged).
- **Frontend contract**: `frontend/src/api/types.ts` rewritten as a complete
  camelCase model of the dashboard payload (Plan/Today/WorkItem/Session
  state/SlotResult/JournalEvent/PlanDetail/...), replacing the lossy stubs
  where most slices were `unknown`. `improveClient` now throws a typed
  `ApiRequestError` carrying `status`/`code`/`details` with a
  `fieldMessage/1` helper for forms (pairs with improve-ash-awdf).
- **Drift check**: `mix ash_typescript.codegen --check` added to the
  `precommit` alias, so the generated RPC contracts can't silently drift.
- Backend tests updated to the camelCase response keys; frontend
  type-checks and builds.

Decision recorded: app-endpoint types stay hand-written (the endpoints are
hand-shaped UiApi payloads, not Ash actions), but are now complete; the
generated `ash_types.ts` continues to cover the RPC read surface.
