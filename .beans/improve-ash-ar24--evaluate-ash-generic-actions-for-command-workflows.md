---
# improve-ash-ar24
title: Evaluate Ash generic actions for command workflows
status: completed
type: task
priority: normal
created_at: 2026-06-22T21:38:29Z
updated_at: 2026-06-22T23:03:30Z
parent: improve-ash-dcal
---

Using current installed Ash docs, evaluate whether start session, log event, correct event, and install demo plan should move toward Ash generic actions or managed actions. Acceptance: short implementation note plus one pilot if it clearly reduces friction.

\n\nCompleted: added notes/ash-command-actions-evaluation.md after checking installed versions and current official Ash docs. Recommendation: keep start session, log/correct event, and demo plan installation as plain Elixir orchestration for now; no pilot was added because it would not reduce friction yet. Revisit generic actions when typed write RPC/API or outer-command policies become necessary. Verification: mise run verify passes with 83 tests.
