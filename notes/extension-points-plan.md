# Extension Points Plan

Draft date: 2026-06-24.

This document resolves the open question at the end of
`improve-model-and-extension-points.md` (section 4, "The Question"). That note
asked how to keep the core small while letting decision logic become much more
flexible. This note is the answer we are committing to, the shape of it, the
staging, and the bar it has to clear.

## 1. Decision

We are pushing in the extension direction: a small, stable, auditable core
plus pure decision evaluators behind an explicit contract.

The core continues to own durable facts and every write. Decision logic -
target evaluation, schedule projection, recommendation, effect generation,
derived metrics, review - moves behind a single evaluator contract that
receives explicit input and returns explicit output plus diagnostics.

This is not a speculative framework. The existing pure planning modules
already follow this shape without anyone having declared it, and the code is
already straining against the inlining of that shape (see section 11). We are
formalizing an emergent pattern, not imposing one from above.

## 2. What "Small Core" Means Here

Small is about responsibility, not line count. The core owns exactly the
durable, auditable, mutating concerns and nothing that is a decision.

The core owns:

- users, plans, tracks, sessions, items, pools, environments
- event types, events, event item links, item effects
- authorization and ownership
- validation
- journal writes and correction history
- transactions

Everything else is a decision, and decisions live outside the core as pure
evaluators. The bright line that keeps this honest is one rule the code already
follows: **decisions are queries, and only the core writes rows.** An
evaluator may propose an effect, a recommendation, or a plan change. The core
decides whether to display it, persist it, or reject it, and it does so inside
a transaction.

If a proposed evaluator needs to write a row, it is not an evaluator. It is a
new core action.

## 3. One Abstraction, Not Nine

The model note listed nine candidate extension points. Reading the existing
code, they collapse to a single shape that the modules already use by
convention:

```text
(intent + world) -> (answer + diagnostics)
```

- target evaluation: (target, history) -> satisfied? + diagnostics
- schedule projection: (schedule, date, history) -> due? + diagnostics
- recommendation: (slot, pools, state, history) -> items + rationale
- effect generation: (event type, payload, links, state) -> effect specs
- derived metric: (metric definition, history, state) -> value
- review: (plan, history, state) -> observations

That collapse is the real win. We build one evaluator framework - a registry,
typed input, typed output, diagnostics always present, versioning - and the
nine "points" become nine built-in evaluator kinds sharing that framework. A
bundle is just a coherent set of evaluators that agree on vocabulary, for
example a marathon bundle that ships a derived-metric evaluator, an adaptation
evaluator, and a recommendation evaluator together.

This also means built-in features and advanced features use the same surface.
The `every_day` schedule, the `fixed` target, and the `subtract_quantity`
effect generator all go through the same contract a future advanced evaluator
would. That dogfooding is the only thing that keeps the contract honest; if
our own built-ins had to cheat around it, no outsider could use it either.

## 4. The Evaluator Contract

Every evaluator implements one behaviour:

```elixir
defmodule Improve.Extensions.Evaluator do
  @callback kind() :: atom()
  @callback capabilities(keyword()) :: [capability()]
  @callback evaluate(input :: map(), opts :: keyword()) :: result()
end
```

Three things make this more than a generic plugin interface.

**Capabilities.** An evaluator declares what it needs rather than receiving
"the whole world." A schedule evaluator declares the schedule, the date, and a
small history slice. An adaptation evaluator declares the plan skeleton, recent
history, and runner state. The host reads these declarations and assembles
exactly that input. This keeps inputs bounded, inspectable, and stable as
history grows, and it is the same model a sandboxed language will want later,
so we only design it once.

**Diagnostics.** The result envelope always carries diagnostics, matching the
convention the Projector and ItemState already use: `{:ok, answer, diagnostics}`
or `{:error, diagnostic}`. Diagnostics are how authoring mistakes and soft
warnings surface to users and plan authors in plain English.

**Purity.** Evaluators do not read the database, the clock, the network, or
randomness, and they do not mutate the journal. They are deterministic
functions of their declared input. This is not aesthetic; it is what makes
offline replay, conflict resolution, caching, and eventual sandboxing tractable.
The hermeticity rule is already established in the four planning modules, so
the expensive constraint is already paid for.

Dispatch is shape-driven by default with explicit override. A `20 pages`
target is recognized as a fixed-amount target without the user naming an
evaluator; named evaluators become the escape hatch for advanced cases. Simple
users never see the registry.

## 5. Evaluators Depend On Each Other

This is the most important architectural finding, and it is invisible until
you try to build something real.

An adaptation evaluator does not compute "consecutive build weeks" or "last
seven days volume" itself. It consumes them. Those are derived metrics, which
means another evaluator produces them, which means the adaptation evaluator's
declared capabilities implicitly say "run the training-load metric evaluator
first and feed its output in."

So evaluators form a dependency graph, not a flat list. The host has to:

1. Read each evaluator's declared capabilities.
2. Resolve which capabilities are other evaluators' outputs.
3. Topologically order and run them, caching outputs.
4. Feed earlier outputs into later evaluators' inputs.

This is the one piece we will design deliberately during stage 1 rather than
discover later. It is invisible while there is one evaluator and painful to
retrofit once there are five. The good news is that the capability-declaration
model is exactly what makes the dependency graph visible and resolvable rather
than implicit; if evaluators just took "the whole world," the graph would be
unknowable and caching, ordering, and sandboxing would all be impossible.

## 6. Adaptation Without Rewriting History

A genuinely adaptive plan - one that responds to illness, injury, holidays,
and missed sessions - must coexist with the immutable journal. It does, as
long as adaptation is split cleanly into two kinds:

**Derived adaptation** lives in projection and is recomputed every time. "You
missed Tuesday, so today you do the long run instead." It is never stored. It
never touches the journal. This is the bulk of good adaptation and it is free
of any write.

**Committed adaptation** is an explicit plan edit. "We are extending your plan
from sixteen to eighteen weeks because of your injury." It mutates plan
structure, so it goes through a core action, ideally with the user's approval.

The evaluator marks which is which. A proposal with `requires_approval: false`
is applied in projection (derived). A proposal with `requires_approval: true`
is surfaced to the user as a suggested plan edit and only becomes real when
the core writes it (committed). Adaptation that tries to "rewrite the
schedule" as a side effect of projection would corrode the auditability that
makes the model worth having; the evaluator returns proposals, the core owns
the write.

## 7. The Trust Ladder

The question "how do authors write extensions without a safe language?" has a
simple answer once capability is separated from trust. Capability is available
from the first tier; it is trust that gates the later tiers.

- **Tier 1 - us.** We write evaluators in Elixir with full access. This is
  where every evaluator starts, including the ones that ship in the product.
- **Tier 2 - trusted partners.** Vetted plan authors write Elixir evaluators
  against the same contract. Not sandboxed, because they are reviewed
  professionals selling in the store. This is the tier where a complex,
  adaptive, sellable plan actually gets built.
- **Tier 3 - untrusted authors.** A safe language, sandboxed, for the day the
  store opens to anyone.

The sandbox is a solution to "how do we let untrusted strangers run code
safely," not to "how do we let an expert encode domain logic." The expert can
encode it in Elixir against the contract today. So the marketplace does not
require a safe language to launch; it requires a safe language to scale to
untrusted authors. That distinction drives the whole staging.

## 8. Staging

Stage 1 - now, internal, pre-launch.

Build the evaluator framework and use it to build at least one genuinely
complex plan ourselves. The contract is internal-only, which is exactly what
gives us freedom to reshape it: no external consumer writes against it, so we
can change it freely in response to what the complex plan exposes. The moment
a partner writes against it, that freedom ends and it becomes a versioned
public API. So versioning starts at stage 2, not stage 1.

Within stage 1, the intended sub-order is:

1. Extract one existing strained seam behind the contract - the schedule
   `cond` in the Projector - as a low-risk probe of the mechanics.
2. Let a second evaluator land, and design the capability-resolution and
   dependency-graph machinery deliberately at that point, before it gets
   hidden under more code.
3. Build the forcing example (section 9) through the contract. If it cannot
   be built cleanly, the contract is not ready; adjust before stage 2.

Stage 2 - post-launch, trusted partners.

Open the contract to vetted plan authors writing Elixir evaluators. The
contract becomes versioned from here onward and evolves deliberately rather
than freely.

Stage 3 - when the store opens to untrusted authors.

Introduce a safe language. This is a separate, larger investment - sandboxing,
tooling, versioning, a security story - and its value is not realized until
there are untrusted authors to serve. It is gated by the contract being proven
and by knowing what untrusted authors actually need to express, which we learn
by watching stages 1 and 2. "Set in stone" is the wrong frame; versioning is
what lets us keep evolving, and the sandbox is a trust-scaling milestone, not
a freeze.

## 9. Success Criterion: The Adaptive Marathon Plan

The product is not a success unless an adaptive marathon training plan can be
made with it. That plan is the forcing example that judges the contract.

Concretely, a marathon plan authored by a trusted coach should be able to take
a runner's baseline (a 5k or 10k time) and a race date, lay out a periodized
plan of three to twelve months, and adapt when the runner takes a holiday,
falls ill, is injured, or misses sessions.

That splits into three layers, each of which wants something different:

- **Structure** - the workouts, periodization phases, weekly templates, pools.
  This is declarative and the existing model is already strong at it. Covered
  without any authored code.
- **Customization** - deriving training paces and plan shape from the baseline
  answers. This is a one-time generation step that emits configured plan data.
  It wants code, but it runs once and its output is auditable static structure.
- **Adaptation** - reshaping today and the future in response to what happened.
  This is the layer that separates a great plan worth paying for from a static
  schedule, and it is where authored evaluators genuinely earn their keep.

Stage 1 must prove that all three layers are expressible, with the adaptation
layer written by us as an internal evaluator. If the contract cannot hold a
credible adaptive marathon plan, the contract is wrong, and we find that out
cheaply because no one external is depending on it yet.

## 10. What This Is Not

To keep stage 1 honest and bounded, the following are explicitly deferred:

- A safe language (Starlark or otherwise). That is a stage 3 concern, gated by
  trust scaling, not capability.
- The in-app plan store and the marketplace surface around it.
- Arbitrary end-user code. End users configure built-in evaluators through the
  existing friendly vocabulary (`fixed`, `every_day`, `subtract_quantity`);
  they do not write evaluators.
- A generic "rules engine." Pushing coaching judgment into a declarative rule
  engine rich enough to hold it would just reinvent a bad programming
  language. Where configuration is enough, we configure; where it is not, we
  use real evaluators.

## 11. Starting Point: The Code Already Wants This

This direction is grounded in the current code, not chosen against it. The
four planning modules already obey the hermeticity rule and already share the
result-plus-diagnostics convention:

- `Improve.Planning.Projector` takes one explicit map and returns work plus
  diagnostics.
- `Improve.Planning.Recommender` takes explicit candidates and returns
  suggestions with reason and source.
- `Improve.Planning.EffectRuleInterpreter` returns effect specs that the caller
  persists - the cleanest existing example of "propose, do not apply."
- `Improve.Planning.ItemState` takes facts and effects and returns state plus
  warnings.

And two functions have grown into hand-rolled, three-tier registries that are
asking to be refactored. `schedule_applies?/3` in the Projector branches on
schedule kind with implemented, recognized-but-stubbed, and unknown tiers, and
`track_target_diagnostics/1` does the same for target types. The
`recognized_unsupported_*` and `unsupported_*` diagnostics those branches emit
are the system itself saying the dispatch wants to be a registry.

The schedule `cond` is therefore the first extraction: move each existing arm
into its own module behind the evaluator behaviour, replace the `cond` with a
dispatch table keyed by schedule kind, and keep the three diagnostic tiers as
registry metadata. If, after that single extraction, the behaviour feels
heavier than the `cond` it replaced or the built-in `every_day` evaluator does
not read cleanly through the contract, the contract is wrong and we stop
before generalizing. That is a cheap probe with a high information payoff, and
it is the right first move of stage 1.
