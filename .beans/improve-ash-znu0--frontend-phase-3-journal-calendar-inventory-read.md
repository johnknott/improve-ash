---
# improve-ash-znu0
title: 'Frontend Phase 3: Journal, calendar, inventory read'
status: in-progress
type: epic
priority: normal
created_at: 2026-08-23T12:58:16Z
updated_at: 2026-08-23T12:58:16Z
---

Phase 3 of notes/frontend-roadmap.md: build trust in what happened and visibility across time. Journal is first because corrections and mobile capture confidence depend on it; Calendar and Inventory read views follow. Durable journal and correction rules stay in Ash/resources and Improve.Journal, while Phoenix provides composed page payloads and Svelte renders them.

## Roadmap

- Journal: newest-first history, filters, pagination, corrected/voided relationships, and event detail.
- Corrections: fix an eligible event through an auditable replacement without deleting history.
- Calendar: ranged projected and actual work in month/week views.
- Inventory: derived current state, warnings, and item effect history.

## Completion Checklist

- [x] Complete the Journal read page and event detail
- [x] Complete corrections from eligible logged events
- [ ] Complete Calendar read flows
- [ ] Complete Inventory read flows
- [ ] Run Phase 3 browser and automated verification
- [ ] Summarize the phase
