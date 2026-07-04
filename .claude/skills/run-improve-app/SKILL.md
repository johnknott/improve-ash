---
name: run-improve-app
description: Launch the Improve app (Phoenix backend + Svelte frontend) and drive it in a real browser with agent-browser, including logging in by reading the OTP from the dev mailbox route. Use when asked to run the app, take screenshots, or visually verify a frontend change end-to-end.
---

# Run and drive the Improve app

## Servers

Check what is already running before starting anything — the user often has
the full dev stack up in a zellij session, and you should reuse it, never
kill it.

```bash
mise run db:up                                       # Postgres on 5433 (idempotent)
curl -s -o /dev/null -w "%{http_code}" http://localhost:4000/api/auth/me
# 200 or 401 → backend already up; anything else → start your own:
(mix phx.server > /tmp/phx.log 2>&1 & echo $! > /tmp/phx.pid)
timeout 60 bash -c 'until curl -s -o /dev/null http://localhost:4000/api/auth/me; do sleep 1; done'

curl -sf http://localhost:5173 > /dev/null || {
  (npm --prefix frontend run dev > /tmp/vite.log 2>&1 & echo $! > /tmp/vite.pid)
  timeout 30 bash -c 'until curl -sf http://localhost:5173 > /dev/null; do sleep 1; done'
}
```

- `mix phx.server` dying with `eaddrinuse` means the dev server is already
  running — that is the reuse case, not an error.
- Vite proxies `/api` → `127.0.0.1:4000`, hardcoded in `frontend/vite.config.ts`.
- If the demo user is missing, `mise run db:seed` creates
  `demo@improve.local` plus the gym and vial demo plans.

## Browser: agent-browser

Installed via mise (`"npm:agent-browser"` in `.mise.toml`). In shells where
it is not on PATH, prefix with `mise x --`.

```bash
mise x -- agent-browser open http://localhost:5173   # explicit http:// — bare
                                                     # localhost:5173 upgrades to
                                                     # https and fails
mise x -- agent-browser snapshot -i                  # interactive elements + @eN refs
mise x -- agent-browser click @e3                    # refs go stale on page change;
                                                     # re-snapshot after every change
mise x -- agent-browser screenshot /tmp/shot.png
mise x -- agent-browser close                        # when done
```

- `wait` takes a CSS selector or milliseconds — NOT Playwright `text=...`
  syntax (that silently times out).
- `eval` rejects top-level `await`; return a promise instead
  (`fetch(...).then(r => r.status)`). It also runs each snippet in a shared
  scope, so `const x = ...` collides across calls with "already declared" —
  wrap multi-statement evals in an IIFE: `(()=>{ const x=...; return x; })()`.
- **Refs (`@eN`) go stale whenever the DOM changes** — reopening a dialog,
  submitting, navigating. Re-`snapshot -i` first, or drive by CSS selector /
  `eval` when a ref might be stale.
- **`console --errors` does NOT capture uncaught exceptions** (e.g. Svelte
  runtime errors that wedge a component). To catch those, inject a listener
  and read it back — see "Catching runtime errors" below.
- Full command reference: `mise x -- agent-browser skills get core`.

## Logging in

OTP codes go to `Improve.Emails.LocalMailbox` (in-memory, per-BEAM). The dev
build exposes the running server's mailbox over HTTP
(`dev_routes: true` in `config/dev.exs`), so read the code directly — no
second node needed. Request a code, read it, verify from the page context:

```bash
EMAIL="demo@improve.local"
curl -s -X POST http://localhost:4000/api/auth/request-code \
  -H 'content-type: application/json' -d "{\"email\":\"$EMAIL\"}" > /dev/null
OTP=$(curl -s "http://localhost:4000/dev/mailbox/latest-otp?email=$EMAIL" \
  | grep -o '"code":"[0-9]*"' | cut -d'"' -f4)
echo "otp: $OTP"

mise x -- agent-browser open http://localhost:5173
mise x -- agent-browser eval "fetch('/api/auth/verify-code',{method:'POST',credentials:'include',headers:{'content-type':'application/json'},body:JSON.stringify({email:'$EMAIL',otp:'$OTP'})}).then(r => r.status)"
# expect: 200
mise x -- agent-browser open http://localhost:5173   # reload as the logged-in user
```

- `/dev/mailbox/latest-otp` returns `{"message":{"code":"...",...}}` (or
  `{"message":null}` if none). Codes live 10 minutes; re-requesting
  invalidates earlier ones.
- Fallback if dev routes are off: mint from a second node sharing the dev DB
  (`PORT=4010 mix run -e '...'` calling `Improve.Accounts.Auth.request_login_code/1`
  — returns bare `:ok` — then `LocalMailbox.latest_otp_for/1`). Verification
  is DB-token based, so any node's code works everywhere.

### Testing as a fresh user (e.g. after a fixture change)

Demo plans are installed once and reused, so a fixture change won't reach an
existing user's plan. Create a throwaway user entirely over the API — any
email works, the code is in the dev mailbox — then complete the profile and
install a demo:

```bash
EMAIL="scratch1@improve.local"   # vary per run
curl -s -X POST http://localhost:4000/api/auth/request-code -H 'content-type: application/json' -d "{\"email\":\"$EMAIL\"}" > /dev/null
OTP=$(curl -s "http://localhost:4000/dev/mailbox/latest-otp?email=$EMAIL" | grep -o '"code":"[0-9]*"' | cut -d'"' -f4)
mise x -- agent-browser open http://localhost:5173
mise x -- agent-browser eval "fetch('/api/auth/verify-code',{method:'POST',credentials:'include',headers:{'content-type':'application/json'},body:JSON.stringify({email:'$EMAIL',otp:'$OTP'})}).then(r=>r.status)"
mise x -- agent-browser eval "fetch('/api/auth/profile',{method:'POST',credentials:'include',headers:{'content-type':'application/json'},body:JSON.stringify({full_name:'Scratch'})}).then(r=>r.status)"
mise x -- agent-browser eval "fetch('/api/app/demo-plans',{method:'POST',credentials:'include',headers:{'content-type':'application/json'},body:JSON.stringify({kind:'gym',date:'2026-07-06'})}).then(r=>r.status)"
mise x -- agent-browser open http://localhost:5173
```

## Catching runtime errors

A Svelte error thrown during render wedges that component's subtree (a dialog
stops closing, a form goes dead) but leaves the rest of the app working — and
`console --errors` misses it. Install a `window.onerror` listener right after
loading, exercise the flow, then read the collected messages:

```bash
mise x -- agent-browser eval "(()=>{window.__errs=[];addEventListener('error',e=>window.__errs.push(e.message));return 'listening';})()"
# ...open the dialog / drive the flow...
mise x -- agent-browser eval "JSON.stringify(window.__errs)"   # [] means clean
```

## Representative check

Logged in, `snapshot -i` should show the sidebar nav (Today, Journal,
Calendar, Plan, Progress, Sessions, Inventory, Event Types, Item Types),
the plan switcher, and the Today page. Screenshot whatever the change
touched and **look at the image** — a blank frame is a failed launch.

## Cleanup

`mise x -- agent-browser close`, then kill only the processes you started
(`kill $(cat /tmp/phx.pid /tmp/vite.pid 2>/dev/null)`). Never kill servers
you found already running.
