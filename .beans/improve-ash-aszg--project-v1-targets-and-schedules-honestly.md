---
# improve-ash-aszg
title: Project V1 targets and schedules honestly
status: completed
type: epic
priority: high
created_at: 2026-06-25T09:54:17Z
updated_at: 2026-06-25T10:43:30Z
parent: improve-ash-8e5j
---

Make projection answer what the product vocabulary promises. Tracks should decide completion/progress through target evaluators instead of the current any-event-on-date shortcut, and monthly/every-N-weeks schedules should project. after_completion and custom remain honestly unsupported for V1.

- Summary of Changes: Target projection now uses target evaluators for completion/progress across fixed, metric, checklist, period-total, progression, and adaptive targets. Monthly and every-N-weeks schedules now project for tracks and session templates. Stories and tests prove the supported shapes, while after_completion and custom remain recognized-but-unsupported with clear diagnostics. Full `mise run verify:backend` is green.
