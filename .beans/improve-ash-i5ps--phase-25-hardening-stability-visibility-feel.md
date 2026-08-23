---
# improve-ash-i5ps
title: 'Phase 2.5: hardening — stability, visibility, feel'
status: completed
type: epic
priority: normal
created_at: 2026-07-05T09:33:48Z
updated_at: 2026-08-23T12:56:31Z
---

Pause on new features (Phase 3 on hold) until we trust what Phases 0-2 built. Driven by real symptoms from John's daily use: BEAM at 300-400% CPU (zellij test-watcher stampede + agent verify runs compounding), intermittent multi-second UI stalls (compile-lock contention on API calls + machine-wide CPU starvation; sidebar nav itself fetches nothing), uncaught Svelte errors invisible to agent tooling, wedged dialog subtrees, orphaned BEAM nodes holding DB pools. Chrome-side lag (many tabs, slow new-tab) is a compounding external factor — instrumentation must distinguish app jank from browser jank. Steady-state backend measured fine (dashboard 30ms).

## Summary of Changes

All five hardening children are complete. The dev loop no longer creates the watcher/verification compile stampede; frontend request/navigation timing is visible; page and dialog boundaries contain failures; the development error badge exposes uncaught browser problems to both people and agent tooling; and the final feel pass delivered accessible loading, safe refresh/cancellation behavior, robust dialog and action focus, responsive navigation, and light/dark theme polish.

The exact finished tree passes `mise run verify` with 309 ExUnit tests, all story scripts, TypeScript and Svelte checks, and a production frontend build. Phase 2.5 no longer blocks Phase 3 Journal and Calendar work.
