---
# improve-ash-60kp
title: Sweep stale V1 naming and spike wording
status: completed
type: task
priority: normal
created_at: 2026-06-25T09:56:05Z
updated_at: 2026-06-25T10:46:20Z
parent: improve-ash-6lsw
---

Fix stale direct_goals naming in frontend/src/api/types.ts and refresh active-code wording that still says spike/POC where the project is now product-bound. Keep archived notes alone unless they are intentionally referenced as current guidance.

- Summary of Changes: Replaced stale direct_goals with tracks in the frontend API type, refreshed active-code spike/POC wording in AI tool/docs, demo setup copy, fixture moduledocs, and planner diagnostics, and updated the matching diagnostic assertion. Left historical notes alone. Verified focused diagnostics/frontend checks and full `mise run verify`.
