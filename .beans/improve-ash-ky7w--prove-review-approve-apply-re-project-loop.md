---
# improve-ash-ky7w
title: Prove review approve apply re-project loop
status: completed
type: task
priority: high
created_at: 2026-06-25T09:55:48Z
updated_at: 2026-06-25T10:58:48Z
parent: improve-ash-qz52
blocked_by:
    - improve-ash-prxm
---

Add backend test/story coverage showing a review or adaptation proposal is approved, apply_proposal extends the plan, and re-projecting reflects the new plan end date. Extend 08_review_and_adjustment.exs or add equivalent focused story assertions.

- Summary of Changes: Added backend coverage and story proof for approve/apply/re-project. App.apply_proposal extends the plan, matching schedule windows move with the plan end date, re-projecting at the new end date shows planned work, and notification handling now publishes Ash notifications after the transaction commits. Verified with focused app tests, story 08, and full mise run verify.
