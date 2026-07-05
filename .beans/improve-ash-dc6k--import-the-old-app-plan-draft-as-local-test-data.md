---
# improve-ash-dc6k
title: Import the old-app plan draft as local test data
status: in-progress
type: task
created_at: 2026-07-05T12:23:59Z
updated_at: 2026-07-05T12:23:59Z
parent: improve-ash-o39y
---

Convert John's improve.plan-draft.v1 export ('Improve myself!' — 21 tracks across metrics/movement/cardio/strength/foundations/health/home/recovery, a vial resource with subtract-on-use, checklist and progression targets) into our improve.plan_draft schema and import it via Plans.import_plan_draft! for the demo user. Deliverable: the export saved under priv/drafts/, a repeatable converter+import script under priv/scripts/, and the plan live in local dev — realistic track-heavy data for the check-in wizard and Today UX work. Also the seed of a future old-app migration feature.
