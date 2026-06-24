# Derived Metric And Adaptation Evaluators

Draft date: 2026-06-25.

## Purpose

This note is the concrete instance of the abstract evaluator dependency
described in `notes/extension-points-plan.md` section 5.

Do not build dependency graph machinery in the abstract. The first real
dependency is the adaptive marathon plan: the marathon adaptation evaluator
needs recent training load, and recent training load should be produced by a
derived-metric evaluator before adaptation runs.

This is design only. It introduces no code, migration, projection shape, or UI.

## Current Grounding

`priv/scripts/stories/10_adaptive_marathon.exs` now proves:

- Layer 1 structure: scheduled marathon run tracks, journal, stateful shoes,
  time-off windows, and review.
- Layer 2 customization: baseline-derived paces written once into track
  guidance, with an auditable customization record.

Layer 3 remains intended product flow. It says adaptation receives recent
history, life events, time-off windows, and derived training load, then returns
today's work plus proposals. It also names the first cross-evaluator dependency:
adaptation consumes derived metrics, so a derived-metric evaluator must run
before the adaptation evaluator.

`Improve.Plans.project_today/2` already assembles the bounded projection input
needed by the producer:

- `date`
- `as_of_date`
- `plan`
- `tracks`
- `journal_events`
- `time_off_windows`

The consumer also needs `projected_work`, which is produced after schedules and
completion state are evaluated. That value is host output from the current
projection pass, not a database input.

The host should keep passing explicit input into evaluators. Evaluators must not
read the database, clock, network, AI, or mutate journal history.

## Producer: Recent Load Derived Metric

The producer is a derived-metric evaluator. Its first metric is deliberately
small:

```elixir
recent_load_km =
  total running kilometers in the 7 days ending on projection.as_of_date
```

Use `as_of_date`, not the projection date. Projection can ask about a future
date while only knowing history through today. For example, a holiday re-entry
projection may look ahead to the first day back, but recent load must be
computed from the latest available history, not future journal entries.

### Declared Input

The producer needs a bounded slice of the projection input:

```elixir
%{
  as_of_date: ~D[2026-07-09],
  window_days: 7,
  tracks: [
    %{id: "...", key: "long_run", guidance: %{"pace" => %{...}}},
    %{id: "...", key: "tempo_run", guidance: %{"pace" => %{...}}}
  ],
  journal_events: [
    %{
      status: :active,
      track_id: "...",
      effective_at: ~U[2026-07-05 20:00:00Z],
      payload: %{"amount" => 18, "unit" => "km"}
    }
  ]
}
```

For this first pass, "running events" means active journal events linked to
marathon running tracks whose payload has a numeric `amount` and `unit` of
`"km"`. Do not introduce a generic track category system yet. The marathon story
already uses the run-completed shape, and that is enough to force the
dependency.

### Output

The producer returns a metric value plus diagnostics:

```elixir
{:ok,
 %{
   recent_load_km: %{
     metric: :recent_load_km,
     value: 46,
     unit: "km",
     window_days: 7,
     as_of: ~D[2026-07-09],
     window_start: ~D[2026-07-03],
     event_ids: ["..."]
   }
 },
 []}
```

Diagnostics should be plain English and non-mutating. Example diagnostics:

- "Ignored run event without a numeric km amount."
- "No active running history exists in the 7-day load window."

The empty-history case is not necessarily an error. For a new plan, a zero load
is a valid metric with a warning-level diagnostic if that helps review language.

## Consumer: Marathon Adaptation Evaluator

The consumer is the marathon adaptation evaluator. It consumes `recent_load_km`
rather than recomputing load.

### Declared Input

The consumer receives a narrower, explicit input assembled by the host:

```elixir
%{
  date: ~D[2026-07-09],
  as_of_date: ~D[2026-07-09],
  plan: %{
    id: "...",
    starts_on: ~D[2026-06-22],
    ends_on: ~D[2026-10-04],
    deadline: %{movable?: false}
  },
  projected_work: [
    %{kind: :track, status: :planned, title: "Tempo run", owner_id: "..."}
  ],
  metrics: %{
    recent_load_km: %{
      value: 46,
      unit: "km",
      window_days: 7,
      as_of: ~D[2026-07-09]
    }
  },
  journal_events: [...],
  life_events: [...],
  time_off_windows: [...],
  track_guidance: %{
    "tempo_run" => %{"pace" => %{"label" => "5:25/km"}}
  }
}
```

Life events are ordinary journal events with typed event types, not a new
resource. Illness and injury happened; they belong in the historical journal.
Planned time off is different: it is plan structure and already has
`time_off_windows`.

For now, the adaptation evaluator can identify life events from active journal
events whose event type key or future event type metadata marks them as
disruption events, such as illness or injury. The exact event-type vocabulary is
deferred to the adaptation implementation beans.

### Output

The consumer returns adaptation output plus diagnostics. The exact projection
field is deferred, but the output must be able to represent:

```elixir
%{
  today: [
    %{
      owner_key: "tempo_run",
      action: :keep,
      reason: "Missed Tuesday intervals dropped, not stacked onto today."
    }
  ],
  proposals: [
    %{
      kind: :shift_session,
      requires_approval: false,
      effect: :derived,
      text: "Missed Tuesday intervals dropped, not stacked onto today."
    },
    %{
      kind: :extend_plan,
      requires_approval: true,
      effect: :committed,
      text: "Illness may delay race readiness; consider extending by 1 week."
    }
  ],
  diagnostics: []
}
```

Use careful language for today's work: adaptation may annotate, suppress,
replace, or propose alternatives for projected work. It does not have to
permanently rewrite schedules. Derived proposals are no-write projection output.
Committed proposals require user approval and later go through a core write.

## Layer 3 Scenario Mapping

The adaptation evaluator must eventually cover the four scenarios from
`10_adaptive_marathon.exs`.

### 3a. Missed Session

Input signal:

- Tuesday intervals were scheduled and not completed.
- Thursday tempo is scheduled.
- `recent_load_km` is available.

Expected output:

- Today's work stays tempo, not tempo plus stacked intervals.
- Proposal: `shift_session` or drop missed quality, `requires_approval: false`.

### 3b. Illness

Input signal:

- Active illness life event in journal with a date range and symptoms.
- Recent load metric.
- Today's projected work.

Expected output:

- Today's work may be suppressed or replaced with rest.
- Derived proposals: `deload_week`, `shift_session`, no approval.
- Committed proposal: `extend_plan`, approval required.

### 3c. Injury

Input signal:

- Active injury life event in journal, such as calf strain with severity.
- Recent load metric.
- Today's projected run.

Expected output:

- Today's run may become rest or cross-train.
- Derived proposal: deload or pause running.
- Committed proposal: extend plan by 1 to 2 weeks, approval required.

### 3d. Holiday Re-Entry

Input signal:

- A `fully_off` time-off window has just ended.
- Recent load metric is low or zero across the time-off window.
- Race date and deadline movability are known.

Expected output:

- First run back may be short and easy.
- Derived proposal: `rebuild_week`, no approval.
- Committed proposal: extend plan if deadline is movable; otherwise suggest
  compressing taper or adjusting the goal.

## Why Adaptation Must Not Inline Recent Load

The adaptation evaluator should not compute `recent_load_km` internally.

1. `recent_load_km` is useful outside adaptation. Review, diagnostics, and
   AshAI context can all use the same metric without duplicating logic.
2. Inline calculation forces adaptation to receive the whole world: full
   history, tracks, payload details, and date-window rules. A declared metric
   input lets the host assemble a bounded, inspectable input.
3. Caching and ordering only work when the dependency is visible. If adaptation
   computes load internally, the host cannot know that training load was needed,
   cannot cache it, and cannot reuse it.
4. Future sandboxing needs declared capabilities. A sandbox can grant
   `recent_load_km` safely; it cannot safely grant arbitrary database-shaped
   history and hope the evaluator behaves.
5. The metric is unit-testable in isolation. That matches the existing pattern
   used by schedules, targets, projection, recommender, item state, and
   customization.
6. The separation preserves the hermeticity rule: producers derive, consumers
   consume, and the core owns every write.

This is the actual reason for capability resolution. Without this dependency,
the graph would be speculative. With it, the graph is forced.

## Implications For Next Beans

### `improve-ash-38rj`

Add minimal capability descriptors. For this concrete dependency, that means:

```elixir
%{
  evaluator: :recent_load_metric,
  provides: [:recent_load_km],
  requires: [:as_of_date, :tracks, :journal_events]
}
```

and:

```elixir
%{
  evaluator: :marathon_adaptation,
  provides: [:marathon_adaptation],
  requires: [
    :projected_work,
    :journal_events,
    :life_events,
    :time_off_windows,
    :plan_skeleton,
    :track_guidance,
    :recent_load_km
  ]
}
```

No general registry, plugin loading, version negotiation, or marketplace
surface is needed yet. The descriptor only needs to make this dependency
visible to the host.

### `improve-ash-44nx`

Add dependency ordering and caching for one concrete graph:

```text
recent_load_metric -> marathon_adaptation
```

The host topologically orders those two nodes, runs the producer once for the
projection input, caches the `recent_load_km` output for that projection run,
and injects it into the adaptation evaluator.

Do not build a broad framework before the two-node chain works. This is the
smallest useful graph.

## Explicit Deferrals

These decisions belong to `q6p8`, `syws`, or the capstone verification bean,
not this note:

- Where `proposals` lives in the Projector return shape.
- How Review displays derived versus committed proposals.
- The exact illness and injury event-type vocabulary.
- Whether adapted work replaces projected work, annotates it, or sits beside it.
- Persistence for accepted committed proposals.
- Generic metric definitions beyond `recent_load_km`.
- Generic graph registry, plugin loading, sandboxing, or evaluator versioning.

## Validation

This design is consistent with the current codebase:

- The producer inputs are already present in `Plans.projection_input/2`.
- The consumer maps to the four Layer 3 story scenarios.
- Life events can use the existing journal model.
- Time off remains plan structure through `time_off_windows`.
- The graph sketch is the minimum needed to satisfy the real dependency:
  `recent_load_metric -> marathon_adaptation`.

No runtime verification is required because this note changes no code.
