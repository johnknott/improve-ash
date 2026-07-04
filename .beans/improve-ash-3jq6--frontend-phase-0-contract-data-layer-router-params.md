---
# improve-ash-3jq6
title: 'Frontend Phase 0: contract, data layer, router params, form kit'
status: in-progress
type: task
created_at: 2026-07-04T21:49:03Z
updated_at: 2026-07-04T21:49:03Z
---

Phase 0 of notes/frontend-roadmap.md — the enabler pass before vertical slices. Scope agreed with John (vocabulary: 'Inventory' stays as the page name, entities are Items/Item Types; 'Resource Types' dies).

## Todo

- [ ] Vocabulary sweep: resource-types → item-types (route id, path, labels); Settings dropdown quirk noted
- [ ] Router: param support (/items/:id shape) in routes.ts + consumers
- [ ] API client: unify authFetch onto ApiRequestError; central 401 → login handling; single request helper ready for idempotency keys
- [ ] Store slices: split appState.ts into dashboard data slices + UI/dialog state, patch merge per slice
- [ ] Form kit: Button (unify two button systems), Field, inputs (text/number/date), Select, Switch, ConfirmDialog, dialog form pattern; refit NewPlanDialog as proof
- [ ] Type tightening: explanations, previousEvents, TargetProgress variants (check backend payload builders)
- [ ] Verify: mise run verify (frontend check + build included)
