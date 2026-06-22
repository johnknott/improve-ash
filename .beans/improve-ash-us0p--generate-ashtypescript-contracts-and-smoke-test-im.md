---
# improve-ash-us0p
title: Generate AshTypescript contracts and smoke test imports
status: completed
type: task
priority: normal
tags:
    - typescript
    - contracts
created_at: 2026-06-22T19:52:29Z
updated_at: 2026-06-22T21:11:05Z
parent: improve-ash-fc2p
---

- [x] Read installed AshTypescript 0.17.3 docs before changing DSL/config.
- [x] Add a small RPC contract surface for representative spike resources.
- [x] Generate committed TypeScript contracts in a documented path.
- [x] Add a tiny TypeScript smoke import check.
- [x] Run verification and close the bean.

## Result

Configured AshTypescript for a headless API contract spike using the installed 0.17.3 docs. Added RPC contract exposure for representative resources: Plan, Item, EventInstance, ItemEffect, and SessionOccurrence.

Generated committed contracts in `priv/generated/ash_types.ts` and `priv/generated/ash_rpc.ts`, with `/api/rpc/run` and `/api/rpc/validate` routes/controller wired for the generated client.

Added `test/typescript/contract_smoke.ts`, `tsconfig.json`, `package.json`, and `pnpm-lock.yaml` so representative generated functions and resource schemas are import/type-checkable. Updated README and mise tasks for regeneration/checking.

Verification:

- `mise run verify`
- `mix ash_postgres.generate_migrations --check`
