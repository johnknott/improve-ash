---
# improve-ash-h0z3
title: Polish app shell visual design (Geist, gold accent, light/dark)
status: completed
type: feature
priority: normal
created_at: 2026-06-25T22:24:58Z
updated_at: 2026-06-25T22:34:15Z
---

Visual polish pass on the Svelte app shell only (no behavior changes). Geist webfont + type scale, CSS token color system (light + dark) with a theme toggle, polished sidebar (brand wordmark, nav icons, active states), polished top bar (sticky, segmented date control, button system), polished bits-ui dropdowns (plan switcher + user menu), and polished card/empty-state surfaces. No new deps beyond the webfont.

## Summary of Changes

Visual-only polish of the Svelte app shell. No behavior changes.

- **Fonts**: Added Geist (variable, self-hosted via `@fontsource-variable/geist/index.css`) with a CSS type-scale.
- **Tokens**: Rewrote `app.css` around CSS custom properties — light + dark palettes selected via `data-theme` on `<html>`, brand accent = gold from the logo, semantic success/warning/danger/info, radii, shadows, type scale.
- **Theme**: `src/lib/theme.ts` store with `localStorage` persistence + system-preference fallback; inline no-FOUC bootstrap script in `index.html`; Sun/Moon toggle in the top bar.
- **Sidebar**: static Improve wordmark row, lucide icon on every nav item, left accent-bar + gold-tinted active state, polished section labels, card-style plan switcher (with a check on the active plan), and a hoverable user chip menu.
- **Top bar**: sticky with backdrop-blur + bottom hairline, centered max-width inner, segmented date stepper, ghost theme toggle, and a consistent primary/secondary/ghost/icon button system with gold focus rings.
- **Dropdowns**: better padding/radius/shadow, leading icons, separators, stronger highlight + keyboard-focus.
- **Surfaces**: polished Card, empty state with a gold icon chip, spinner on the loading shell, json-block uses the mono stack.
- **Bug fixed along the way**: `LoadingState` referenced an undefined `.loading-dot` — added a real spinner.

Verified with `npm run check` (0 errors/warnings) and `npm run build` (clean).
