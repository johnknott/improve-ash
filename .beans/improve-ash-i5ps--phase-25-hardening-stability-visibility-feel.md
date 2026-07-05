---
# improve-ash-i5ps
title: 'Phase 2.5: hardening — stability, visibility, feel'
status: in-progress
type: epic
created_at: 2026-07-05T09:33:48Z
updated_at: 2026-07-05T09:33:48Z
---

Pause on new features (Phase 3 on hold) until we trust what Phases 0-2 built. Driven by real symptoms from John's daily use: BEAM at 300-400% CPU (zellij test-watcher stampede + agent verify runs compounding), intermittent multi-second UI stalls (compile-lock contention on API calls + machine-wide CPU starvation; sidebar nav itself fetches nothing), uncaught Svelte errors invisible to agent tooling, wedged dialog subtrees, orphaned BEAM nodes holding DB pools. Chrome-side lag (many tabs, slow new-tab) is a compounding external factor — instrumentation must distinguish app jank from browser jank. Steady-state backend measured fine (dashboard 30ms).
