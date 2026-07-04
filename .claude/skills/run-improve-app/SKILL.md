---
name: run-improve-app
description: Launch the Improve app (Phoenix backend + Svelte frontend) and drive it in a real browser with agent-browser, including logging in as the demo user by minting an OTP from a second backend node. Use when asked to run the app, take screenshots, or visually verify a frontend change end-to-end.
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
  (`fetch(...).then(r => r.status)`).
- Full command reference: `mise x -- agent-browser skills get core`.

## Logging in as the demo user

OTP codes are delivered to `Improve.Emails.LocalMailbox` — an in-memory
Agent inside whichever BEAM generated them. You cannot read the running dev
server's mailbox, and driving the UI email step mints a code you will never
see. Instead, mint a code from a second backend node sharing the dev DB —
verification is DB-token based, so any node's code is valid everywhere:

```bash
OTP=$(PORT=4010 mix run -e '
:ok = Improve.Accounts.Auth.request_login_code("demo@improve.local")
IO.puts("OTP=" <> Improve.Emails.LocalMailbox.latest_otp_for("demo@improve.local").code)
' 2>&1 | grep '^OTP=' | cut -d= -f2)
echo "minted: $OTP"
```

- `PORT=4010` avoids `eaddrinuse` with the running server.
- `request_login_code` returns bare `:ok`, not `{:ok, _}`.
- Codes live 10 minutes; requesting again invalidates earlier codes.
- OTP rate limits are per-node ETS, so the fresh node never trips them.

Then set the session cookie from the page context and reload:

```bash
mise x -- agent-browser open http://localhost:5173
mise x -- agent-browser eval "fetch('/api/auth/verify-code',{method:'POST',credentials:'include',headers:{'content-type':'application/json'},body:JSON.stringify({email:'demo@improve.local',otp:'$OTP'})}).then(r => r.status)"
# expect: 200
mise x -- agent-browser open http://localhost:5173
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
