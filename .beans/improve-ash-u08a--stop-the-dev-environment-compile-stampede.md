---
# improve-ash-u08a
title: Stop the dev-environment compile stampede
status: completed
type: task
priority: normal
created_at: 2026-07-05T09:33:48Z
updated_at: 2026-07-05T09:36:15Z
parent: improve-ash-i5ps
---

Kill orphaned BEAM nodes (Jul 3 orphan + hung mix test runs from watchexec --restart races). Edit scripts/zellij-dev.kdl: drop --restart (the orphan-maker; queues instead of kill-races) and add a debounce so bursts of agent saves trigger one test run, not a dozen. AGENTS.md note: while the user's dev session is live, run targeted tests during iteration, not repeated full verifies — the watcher already tests on save; save mise run verify for handoff.

## Summary of Changes
Killed the Jul 3 orphaned BEAM and two mix test runs hung for 10 hours (left as reaped-on-next-cycle zombies under watchexec). Root-caused the "20 DB sessions": two healthy pools of 10 (Phoenix + the iex pane) — normal footprint, not a leak; the pg timestamp confusion was container-UTC vs host-BST. zellij-dev.kdl watcher: dropped --restart (the orphan-maker — killing a mid-run BEAM races and leaves nodes holding pools) and added --debounce 3000 so agent save-bursts trigger one test run. AGENTS.md: agents must run targeted tests during iteration and save mise run verify for handoffs while the user's dev session is live.
