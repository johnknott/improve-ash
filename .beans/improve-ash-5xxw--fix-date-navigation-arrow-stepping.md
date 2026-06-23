---
# improve-ash-5xxw
title: Fix date navigation arrow stepping
status: completed
type: bug
priority: normal
created_at: 2026-06-23T18:25:29Z
updated_at: 2026-06-23T18:25:52Z
---

Date navigation should move exactly one day in either direction.\n\n- [x] Replace timezone-sensitive Date parsing in selected-date stepping\n- [x] Verify previous and next arrows produce adjacent ISO dates\n- [x] Run frontend checks\n\n## Summary of Changes\n\nReplaced local-midnight Date parsing in stepSelectedDate with ISO-date arithmetic using UTC noon and manual formatting. This avoids timezone and DST shifts where previous could jump two days or next could appear unchanged.\n\nVerified with npm run check and npm run build.
