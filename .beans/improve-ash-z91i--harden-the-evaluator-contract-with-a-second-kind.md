---
# improve-ash-z91i
title: Harden the evaluator contract with a second kind
status: draft
type: epic
priority: normal
created_at: 2026-06-24T20:37:34Z
updated_at: 2026-06-24T20:37:41Z
parent: improve-ash-zkg7
---

After the schedule probe proves the shape, use one additional evaluator kind to harden the internal contract.

Likely candidate: target diagnostics, because the current code already has implemented, recognized-unsupported, and unknown tiers similar to schedules.

Do not start this until schedule evaluators feel lighter than the cond they replaced.
