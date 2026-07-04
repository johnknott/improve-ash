# Improve — Future Vision

Draft date: 2026-07-04.

## Purpose

This is the excited-but-honest version of where Improve goes after the V1
hardening work (`notes/fable-todo.md`) and the Svelte web app. It describes
the product a few years out, the pillars that get us there, and the order to
build them in. The near-term discipline docs still win any conflict: the
purity boundary, the product vocabulary, and the append-only journal are
non-negotiable foundations, not V1 scaffolding.

## North Star

Improve is the system that holds your intentions and helps you live them. You
author a plan once — or just describe it to your coach — and from then on the
product meets you wherever you are: a glance at your phone tells you what
today looks like, a sentence spoken out loud logs what actually happened, a
weekly review explains what changed and why, and the plan quietly adapts to
illness, travel, and real life through proposals you approve. The same brain
is reachable from the web studio, the mobile companion, a terminal, or any AI
assistant you already use.

## Why Ash Makes This Cheap

We model the domain once and derive everything else. This is the strategic
bet of the whole codebase, and it compounds:

- **Contracts and clients for free.** `ash_typescript` already generates the
  TS contracts. `ash_json_api` and `ash_graphql` are one extension away if
  partners ever need standard APIs. Tools like `ash_cli` prove the pattern's
  ceiling: a polished cross-platform Go CLI generated from Ash metadata,
  acting as a true remote client that enforces server-side policies,
  validations, and tenancy without duplicating any business logic. An
  `improve` CLI for power users and agents is a weekend, not a quarter.
- **AI as a first-class derivation.** `ash_ai` gives us prompt-backed actions
  (LLM-implemented actions with structured, type-safe outputs), tool
  definitions derived from our own actions, pgvector vectorization for RAG
  over the journal (async via `ash_oban`), and a production MCP server. Our
  read-only AI tools (`Improve.Ai.ReadTool`) already run through Ash policies
  — the coach inherits multi-user isolation for free.
- **An OAuth server in a box.** `ash_authentication_oauth2_server` is a full
  OAuth 2.1 authorization server — PKCE, dynamic client registration,
  discovery metadata — designed precisely for hosting authenticated MCP
  servers for remote clients like Claude connectors. "Connect your assistant
  to your plan" becomes configuration, not a platform project.

## Pillar 1 — The Coach

The differentiator. Not a chatbot bolted onto a tracker: a coach grounded in
the deterministic engine we already built.

**Architecture: the engine decides, the coach explains and negotiates.**
The evaluator graph produces derived adjustments and committed proposals with
diagnostics and reasons. The LLM's jobs are the ones LLMs are good at:

- Narrate today: "You're still inside the post-fever rest window, so the
  intervals were swapped for rest. Two more easy days and you're back."
- Run the weekly review as a conversation, backed by the deterministic
  `App.Review` output and RAG over the vectorized journal ("when did my knee
  last complain?").
- Translate intent into structure: "make Thursdays easier" becomes a
  committed proposal through the same approval pipeline as evaluator
  proposals.

**The safety invariant: the coach never writes directly.** Every durable
change the AI wants flows through the proposal surface — described,
attributed, approved, then applied by core actions. This is the same trust
ladder we designed for third-party evaluators, applied to the LLM. It keeps
the coach trustworthy and keeps the journal honest.

**Plan authoring by conversation.** The mobile app shouldn't carry the full
authoring UI — screens are small and plans are deep. Instead the coach
interviews you ("marathon in October, three days a week, dodgy left knee")
and emits a `PlanDraft` — our existing validated, importable, previewable
format. The draft preview *is* the confirmation UI. This turns the mobile
screen constraint into a better creation experience than forms on any screen.

**Voice.** On mobile, voice is the primary capture and coaching channel:
"log twelve k easy, felt strong" → structured event through the event
contract; "what's left today?" → projection narration. Realtime voice models
(Gemini Live, Grok voice, OpenAI Realtime) are moving fast — we keep the
voice layer a thin adapter over the same tool-calling core so we can swap
models without touching the domain.

## Pillar 2 — Improve Everywhere (MCP + OAuth)

Ship an authenticated MCP server so any assistant a user already lives in —
Claude, ChatGPT, their IDE, their home automation — becomes a client of
*their* plan, gated by OAuth and Ash policies.

- Read tools first (already built): project today, plan summary, journal,
  item state.
- Then careful write tools: `log_event` (idempotent, same keys as mobile) and
  `propose_plan_change` (proposal pipeline only — external assistants get
  even less direct write power than our own coach).
- The web studio gets a "Connections" page: authorized clients, per-device
  tokens, revocation — the same token infrastructure the mobile app needs
  anyway.

This is a moat. Every tracker has an app; almost none are a first-class
citizen of the user's own AI ecosystem.

## Pillar 3 — The Surfaces

Each surface derived from the same domain, each shaped for its moment:

- **Web studio (build first).** The place for deep work: full plan authoring,
  pool/session/schedule editing, rich dashboards, review sessions, template
  import/export, connections management. Already underway in `frontend/`.
- **Mobile companion (the daily driver).** Capture-first. Most people touch
  Improve here, many times a day, for seconds at a time.
- **CLI + MCP (the power surfaces).** Generated, policy-enforcing, always
  current with the domain.

We don't need 100% of the web app before starting mobile. Once the capture
loop (auth, today view, logging, offline outbox) works, the mobile app is
genuinely useful in the field and becomes its own best test harness.

## Pillar 4 — The Mobile App

**Recommendation: Flutter, one codebase.** The deciding factor is the design
ambition itself: we explicitly do *not* want stock Material or stock native.
Flutter's rendering stack (Impeller) treats custom fragment shaders as a
first-class feature, and one bespoke design system is expensive enough —
building it twice natively doubles the cost of exactly the part we care most
about. Native remains the fallback if we ever hit a platform wall (deep
HealthKit edge cases, watch complications), and the API contract keeps that
door open.

**Visual identity.** Custom everything. A living shader background — subtle
plasma drifting through hues on a deep dark field (the new Gemini app is the
reference point) — with the day's projection floating above it. Motion that
responds to progress: the background warms as the day's work completes.
Custom typography, custom controls, zero Material affordances. The app should
feel like an object, not a form.

**Capture above all.** Log-in-two-taps from anywhere; voice logging; home
screen and lock screen widgets showing today's remaining work; notifications
driven by projected sessions (this is what finally pulls Oban into the
stack). Later: watch companion, geofenced environment awareness (the
`Environment` concept already models "what's possible here"), and health
platform ingestion — HealthKit / Health Connect workouts arriving as events
with `origin: :imported`, deduped by the same idempotency machinery.

**Offline is already designed.** The server-side outbox contract —
client-generated operation IDs, idempotent retries, batch submission,
per-entry conflict categories — is implemented and story-tested. The mobile
app is its missing client: a local outbox that drains through the batch
endpoint whenever there's signal. Resilient capture, not CRDT sync — exactly
as `notes/offline-journal-ingress.md` scoped it.

## Pillar 5 — The Ecosystem

Further out, but the architecture already points here:

- **Template marketplace.** `PlanDraft` export/import is the seed: share,
  browse, and remix plans ("couch to 5k", "GCSE revision", "cutting phase").
  Customization recipes (baseline → derived guidance) make templates
  personal on import.
- **Third-party evaluators.** The trust ladder from
  `notes/extension-points-plan.md`: us → trusted partners → sandboxed
  community authors. An adaptive-strength bundle, a study-plan bundle, an
  inventory-replenishment bundle — each just descriptors + pure functions.
- **Human coaches.** A coach role that can view a client's plan, journal, and
  proposal history through the web studio, and submit proposals through the
  same approval pipeline as the AI and the evaluators. One pipeline, three
  kinds of authors.

## Sequencing

1. **Now:** V1 hardening (`notes/fable-todo.md`) — idempotent logging, bearer
   tokens, timezones, offline HTTP ingress, contract cleanup. Every item
   there is load-bearing for this vision.
2. **Web studio:** authoring, dashboards, review; proposal surface rendered
   for the first time.
3. **Mobile foundation:** Flutter shell, custom design language, auth, today
   view, logging + offline outbox. Ship to ourselves early; daily-drive it.
4. **Coach v1 (text):** ash_ai tool loop over existing read tools + proposal
   writes; journal vectorization; review-as-conversation.
5. **Voice + notifications:** realtime voice capture and coaching; Oban-driven
   reminders from projected sessions.
6. **MCP + OAuth:** authenticated MCP server, connections management, the
   assistant-ecosystem play.
7. **Ecosystem:** template sharing, partner bundles, human coaches.

## Principles To Protect Along The Way

- The planning core stays pure; intelligence lives at the edges.
- The journal stays append-only; corrections, never edits.
- AI and third parties change plans only through proposals with approval.
- The product vocabulary is the API — every new surface speaks Plan, Track,
  Session, Event, not implementation words.
- Model the domain once; derive every surface from it.
