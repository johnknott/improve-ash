---
# improve-ash-hl8l
title: Add server-seeded UI bootstrap data
status: draft
type: feature
priority: deferred
created_at: 2026-06-25T12:06:30Z
updated_at: 2026-06-25T12:06:30Z
---

Defer a lightweight hydration/bootstrap path for the Svelte app so Phoenix can serve the initial HTML shell with user/current-plan/page seed data embedded as JSON. This is intentionally not full SSR: Svelte still renders on the client, but the first render can use real bootstrap data instead of flashing through an empty/loading shell.\n\nWhy defer: wait until the UI shape is more stable and we can feel the benefit on real pages before changing the app-serving path.\n\nPotential shape:\n- Phoenix serves the app HTML shell in production, with Vite/dev assets in development.\n- Embed a small application/json bootstrap payload for session/user/current-plan/page summary.\n- Svelte reads the bootstrap payload before mount and hydrates normal client state from it.\n- Normal Phoenix app endpoints and AshTypescript RPC calls continue to handle refreshes and mutations after first render.\n\nDone when:\n- The logged-in app can first-render with useful current-user/current-plan data already present.\n- The approach avoids full SSR component execution and avoids server/client render mismatch complexity.\n- Any bootstrap payload is authorized, minimal, and safe to embed in HTML.\n- Dev and production serving paths are documented clearly.
