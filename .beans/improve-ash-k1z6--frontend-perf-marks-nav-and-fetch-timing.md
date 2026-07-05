---
# improve-ash-k1z6
title: 'Frontend perf marks: nav and fetch timing'
status: completed
type: task
priority: normal
created_at: 2026-07-05T09:33:48Z
updated_at: 2026-07-05T09:40:48Z
parent: improve-ash-i5ps
blocked_by:
    - improve-ash-6401
---

Dev-only: time route switch to post-paint and every API request; log to console, and route slow ones (>300ms) through console.warn so they surface in the error badge. Turns 'the page felt slow' into a number that also distinguishes app jank from browser jank (Chrome tab-pressure vs our code).

## Summary of Changes
Dev-only timing: navigate() measures route-switch to post-paint (double rAF); http.ts request() times every API call. Fast → console.debug; slow (nav >250ms, request >300ms) → console.warn, which lands in the dev badge/__improveErrors. Baseline measured: nav 7-11ms, dashboard GET 32ms — so the next "2-second page switch" produces a number and a culprit, and distinguishes app jank from browser jank (Chrome tab pressure shows normal marks; app problems show slow ones).

## Addendum: main-thread stall attribution
First real catch in the wild: nav → sessions 1234ms with no slow request mark — backend exonerated, pure main-thread stall. Added lib/perfWatch.ts: a Long Animation Frames observer (Chrome 123+) that warns with per-script attribution when a frame blocks >200ms — our modules (localhost path), an extension (chrome-extension://), or "no script attribution" (GC/extension isolate/system pressure). Warns land in the badge. Verified with a forced 400ms block. Note from John's console: overrideMethod@installHook.js means React DevTools' console hook is active in his tab — extensions are on the suspect list.
