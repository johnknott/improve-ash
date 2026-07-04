---
# improve-ash-3jq6
title: 'Frontend Phase 0: contract, data layer, router params, form kit'
status: completed
type: task
priority: normal
created_at: 2026-07-04T21:49:03Z
updated_at: 2026-07-04T22:15:55Z
---

Phase 0 of notes/frontend-roadmap.md — the enabler pass before vertical slices. Scope agreed with John (vocabulary: 'Inventory' stays as the page name, entities are Items/Item Types; 'Resource Types' dies).

## Todo

- [x] Vocabulary sweep: resource-types → item-types (route id, path, labels); Settings dropdown quirk noted
- [x] Router: param support (/items/:id shape) in routes.ts + consumers
- [x] API client: unify authFetch onto ApiRequestError; central 401 → login handling; single request helper ready for idempotency keys
- [x] Store slices: split appState.ts into dashboard data slices + UI/dialog state, patch merge per slice
- [x] Form kit: Button (unify two button systems), Field, inputs (text/number/date), Select, Switch, ConfirmDialog, dialog form pattern; refit NewPlanDialog as proof
- [x] Type tightening: explanations, previousEvents, TargetProgress variants (check backend payload builders)
- [x] Verify: mise run verify (frontend check + build included)

## Summary of Changes

- `app/routes.ts`: `activeRoute` is now `{ route, params }`; route paths support `:param` segments with `buildPath`/pattern matching; `resource-types` renamed to `item-types`; dead `subtitle` field dropped. Consumers (Sidebar, AppShell) updated.
- `api/http.ts` (new): shared `request` helper — auto-JSON bodies, `ApiRequestError` everywhere (auth client included), central 401 → clears auth state → login screen (`notifyUnauthorized: false` on auth endpoints). Single choke point for future idempotency keys.
- `app/appState.ts` split into `app/dashboardState.ts` (per-slice stores `plans`/`currentPlan`/`today`/`journal`/`planDetail`, `applyDashboardPatch` per-slice merge, load/mutations/date actions) and `app/uiState.ts` (dialogs + toast). Plan form submissions now rethrow the original `ApiRequestError` for field-level display instead of a generic banner.
- Form kit in `components/ui/`: Button (variants over the one remaining button system — bare `form > button` slab styles removed, auth pages refitted), Field (label/hint/error + `.has-error` input styling), TextInput/NumberInput/DateInput/Select (generic), Switch (bits-ui), FormDialog, ConfirmDialog. `EmptyState` gained an icon snippet; PlaceholderPage uses it instead of hand-rolled markup.
- `NewPlanDialog` rebuilt on FormDialog/Field with client + API field-level errors; date math moved to shared `lib/dates.ts`.
- `api/types.ts`: `explanations: string[]`, typed `RecommendationPreviousEvent`, `TargetProgress` is now a 7-variant union matching the backend evaluators (verified against `lib/improve/planning/targets/*`).
- Also swept in: `mix format` fixes and regenerated `priv/generated/ash_types.ts` (`targetSnapshot`, `evaluatorBundles`) that the earlier coaching-foundations commits had left stale — `mise run verify` now passes end-to-end.
- Visually verified in headless Chrome: login, dashboard (sidebar says "Item Types"), plan dialog, field-error states. Zero console errors.
