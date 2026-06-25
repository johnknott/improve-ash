# Adaptive Marathon Lessons

Draft date: 2026-06-25.

## Purpose

The adaptive marathon plan was never meant to become a finished training
product. Its job was to stress the Improve model, test the evaluator contract,
and expose what the rest of the product needs before we build more UI or open
extension authoring to anyone else.

On that basis, it worked. The plan is rough as coaching, but useful as product
research. It forced the model to handle structure, customization, derived
adaptation, committed proposals, evaluator dependencies, diagnostics, and story
output in one coherent example.

## What We Proved

The core model can hold a complex authored plan without special marathon-only
resources.

The story now covers:

- a real weekly running template with long, tempo, intervals, and easy tracks
- scheduled projection by weekday
- journaled run completion
- linked stateful items, including race-shoe wear through item effects
- low-quantity item warnings
- baseline customization that writes static guidance once
- an auditable customization record
- a derived-metric evaluator for recent running load
- a marathon adaptation evaluator consuming that metric
- derived no-write adaptation proposals
- committed approval-required plan-edit proposals
- evaluator graph ordering and caching
- story output that shows the layers together

That is enough to say the extension-point direction is real rather than only a
diagram.

## The Main Discoveries

### 1. Structure, Customization, And Adaptation Are Different Layers

The three-layer split held up.

Structure is declarative plan data: tracks, schedules, targets, item types,
items, and time-off windows.

Customization is a one-time generation step: a baseline 5k time becomes static
track guidance, written onto the plan and recorded as an auditable
customization run.

Adaptation is projection-time decision logic: it reads the current situation and
returns today's adjusted work plus proposals. It does not mutate the journal or
quietly rewrite the plan.

This distinction should stay central. It keeps the product explainable, keeps
projection pure, and stops adaptive plans from becoming hidden state machines.

### 2. The Capability Graph Was Forced By A Real Dependency

The marathon adaptation evaluator needs recent running load, but it should not
calculate that load itself.

That gave us the first real evaluator dependency:

```text
recent-load derived metric -> marathon adaptation
```

This justified the minimal graph runner. It also validated the principle from
`notes/extension-points-plan.md`: evaluators declare bounded inputs and prior
outputs they require. The host orders them, runs them, caches outputs, and
injects results.

This is much better than giving evaluators "the whole world" and letting each
one rediscover its own dependencies.

### 3. Derived And Committed Adaptation Must Stay Separate

The marathon scenarios made this separation concrete.

Derived adaptation is no-write projection output. Examples:

- do not stack missed intervals onto today's tempo run
- deload after illness
- cross-train or rest during injury
- restart gently after holiday

Committed adaptation is a proposed plan edit. Examples:

- extend the plan by one week
- extend by two weeks after a more severe injury
- adjust the goal when the deadline cannot move

Committed proposals must require approval and later go through core actions.
Projection may propose them, but must not perform them.

### 4. Life Events Can Start As Journal Events

Illness and injury do not need a separate resource yet. They are things that
happened, so they fit the journal.

Planned time off remains different. It is authored plan structure, represented
by time-off windows.

The exact illness/injury vocabulary still needs design, but the direction is
clear enough: disruption events can be ordinary journal events with typed event
types and payloads.

### 5. The Story Layer Is A Good Laboratory, But Not The Final API

The marathon story helped us move quickly and keep output readable. That is
exactly what stories are for.

Some helpers now look like real product operations and may eventually belong in
`Improve.App`. Others are just story scaffolding and should stay there.

The useful test is still: if the future UI would call it, promote it toward the
app facade. If it only makes a demo script easier to read, leave it in
`Improve.Stories`.

### 6. The Marathon Logic Should Not Be Treated As Coaching Quality

The current adaptation rules are deliberately small and simple. They are not a
training product, and they should not be polished as if they were.

Their value is that they forced product architecture questions:

- where do derived metrics live?
- how does one evaluator consume another?
- how are no-write suggestions represented?
- how are approval-required edits represented?
- what does review need to explain?
- what facts does projection need to carry forward?

That was the point of the exercise.

### 7. Bundle Logic Should Stay Out Of The Core Namespace

The generic planning core should not carry marathon-specific modules just
because the marathon story was the first forcing example.

The reusable pieces are the evaluator graph, capability helpers, projection
model, journal model, and future proposal model. The marathon-specific pieces
belong in a bundle namespace:

- pace derivation from a running baseline
- recent running load
- marathon adaptation rules
- approval-required race-plan edit proposals
- the concrete marathon evaluator pipeline
- the marathon evaluator descriptors

This keeps the forcing example useful without letting it harden into product
kernel vocabulary.

## What Still Feels Rough

### Projection Output Needs A Proposal Surface

Today, proposal output is proven through the marathon story and evaluator
result, but the general projection shape still needs a first-class place for:

- derived proposals
- committed proposals
- required approval
- proposal reasons
- proposal source evaluator
- affected work or plan fields

This should not be marathon-specific. The same shape will be needed for session
recommendations, adaptive item work, review, and future authored evaluators.

### Review Needs To Understand Adaptation

Review should eventually be able to explain:

- what changed today and why
- what was deliberately not stacked or carried forward
- which suggestions are safe derived projection changes
- which suggestions are durable plan edits requiring approval
- what evidence each suggestion used

The marathon story currently prints enough to prove the contract, but review is
not yet a proper consumer of adaptation proposals.

### Event Vocabulary Needs Tightening

Illness and injury can be journal events, but the event-type vocabulary is not
settled.

We probably need product-facing conventions for disruption events:

- illness with date range, symptoms, and severity/flags
- injury with body area, severity, and activity restrictions
- missed planned work
- maybe travel or unusually high fatigue later

The model should stay generic, but product templates need consistent shapes.

### Recent Load Is Only The First Derived Metric

Seven-day running load was the smallest useful metric. It proved the dependency
graph, but richer adaptation will need more derived metrics, such as:

- consecutive build weeks
- acute/chronic load ratio
- days since last quality session
- days since last long run
- recent missed-work count
- recent pain/illness flags

We should add these only when another story or evaluator really needs them.

### The Capability Contract Is Still Internal

That is good for now. We are still free to reshape it.

Before trusted partners or plan authors use this contract, it will need:

- a clearer behaviour boundary
- stable input and output envelopes
- versioning rules
- diagnostics conventions
- probably better typed proposal structs
- a sharper distinction between built-in evaluators and authored evaluators

Do not freeze this too early.

## Good Next Work

### 1. Generalize Proposal Output

Create a backend-only proposal shape that projection, review, and evaluators can
share.

It should cover both:

- derived projection suggestions that need no approval
- committed plan-edit proposals that require approval

This is probably the most important next product-shaping task from the marathon
work.

### 2. Thread Proposals Through Projection And Review

Once the proposal shape exists, projection should be able to return proposals
alongside projected work and diagnostics.

Review should then summarize those proposals in plain English, without becoming
the place where adaptation logic lives.

### 3. Define Disruption Event Conventions

Keep illness and injury as journal events, but define the event-type payload
shapes that templates and stories should use.

This would make adaptation less ad hoc and give future UI/API work a cleaner
target.

### 4. Promote Real Product Operations Out Of Stories

Audit the marathon helpers and decide which are real app-facing operations.

Likely candidates:

- running an evaluator-backed adaptation pass
- showing/returning proposal output
- reading adaptation context for review

Keep demo-only lookup and printing helpers in `Improve.Stories`.

### 5. Add One More Non-Marathon Forcing Example Later

Do not do this immediately if the backend backlog has more obvious work, but
eventually we should prove the same evaluator/proposal shape with a second
domain.

Good candidates:

- adaptive strength/session work
- study plan adaptation
- stock/inventory replenishment suggestions

The goal would not be another large demo. It would be to find what was
marathon-specific before the extension contract hardens.

## What Not To Do Next

Do not build UI for this yet. The backend shape is still learning.

Do not polish the marathon coaching logic as if it were the product.

Do not build a generic rules engine.

Do not add a sandbox or untrusted author runtime yet.

Do not make the evaluator contract public or versioned until it has survived at
least one more serious pass.

## Working Conclusion

The adaptive marathon plan served its purpose. It turned the extension-point
idea into running backend code, showed where the evaluator graph is necessary,
and exposed the next important product shape: proposals as first-class output.

The next phase should keep the same discipline: backend first, story proven,
small core owns writes, evaluators stay pure, and anything adaptive must explain
whether it is a temporary projection decision or a durable plan edit waiting for
approval.
