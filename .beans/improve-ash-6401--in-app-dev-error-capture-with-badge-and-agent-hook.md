---
# improve-ash-6401
title: In-app dev error capture with badge and agent hook
status: completed
type: feature
priority: normal
created_at: 2026-07-05T09:33:48Z
updated_at: 2026-07-05T09:40:48Z
parent: improve-ash-i5ps
---

Dev-only module installed from main.ts: window.onerror + unhandledrejection + console.error/warn tee into a ring buffer exposed as window.__improveErrors, with a small fixed badge showing the count (click = dump details to console, clear). John sees errors the moment they happen; agent sessions poll __improveErrors after every interaction — no per-session listener setup, present from first paint. Update run-improve-app skill to poll it. Sentry deliberately deferred until there is a deployment.

## Summary of Changes
lib/devErrors.ts installed from main.ts before mount (dev only): window.onerror + unhandledrejection + console.error/warn tee → 100-entry ring buffer, exposed as window.__improveErrors and as the devErrors store. DevErrorBadge (bottom-left, red for errors / amber for warnings-only; click dumps to console via console.info and clears). Skill updated: poll __improveErrors after every interaction — replaces the manual listener recipe. Verified live: thrown error → badge "1 problem" + buffer entry with stack context; click → cleared. Sentry deliberately deferred until a deployment exists.
