alias Improve.App
alias Improve.Stories, as: Story

# =============================================================================
# Adaptive Marathon Plan — product story (DRAFT)
#
# This is the forcing example for the evaluator contract described in
# notes/extension-points-plan.md. It is written product-first.
#
# The runnable sections prove the declarative core can hold a marathon plan
# today. The clearly-fenced INTENDED sections specify what the adaptation
# evaluator must produce before this plan is genuinely adaptive — so this
# story doubles as the spec for the downstream marathon beans.
#
# Layers:
#   Layer 1 - Structure ............ declarative weekly template. RUNS today.
#   Layer 2 - Customization ........ one-time pace derivation.   INTENDED.
#   Layer 3 - Adaptation ........... responds to misses / illness / injury /
#                                   holiday.                      INTENDED.
#
# Runner: Alex. Baseline: 25:00 5k. Race: Berlin Marathon, 2026-10-04.
# Goal: sub-4:00.
# =============================================================================

story =
  Story.begin!("adaptive_marathon", reset?: true)
  |> Story.user!("Alex", email: "story+adaptive-marathon@example.test")

actor = story.user

plan =
  App.create_plan!("Berlin Marathon",
    actor: actor,
    intention: "Train for a sub-4:00 Berlin Marathon, adapting around life",
    from: ~D[2026-06-22],
    until: ~D[2026-10-04]
  )

# -----------------------------------------------------------------------------
# Layer 2 input — Baseline (the single value the plan customizes around)
# -----------------------------------------------------------------------------

App.add_event_type!(plan, "Time trial",
  actor: actor,
  key: "time_trial",
  payload: %{required: ["distance_km", "minutes"]}
)

App.log_event!(plan,
  actor: actor,
  event: "time_trial",
  on: ~D[2026-06-21],
  summary: "5k baseline: 25:00",
  payload: %{distance_km: 5, minutes: 25}
)

# See the Layer 2 INTENDED block near the end: training paces are derived from
# this baseline once, at customization time. Until then the structure below
# uses plain distance targets.

# -----------------------------------------------------------------------------
# Layer 1 — Structure (declarative; runs today)
#
# Weekly template: Tue intervals, Wed + Sat easy, Thu tempo, Sun long run.
# Each run is logged against a shared "Run completed" event that also wears
# out the linked shoes — the same shape as the dose / vial inventory story.
# -----------------------------------------------------------------------------

App.add_item_type!(plan, "Running shoes",
  actor: actor,
  key: "running_shoes",
  facts: [:starting_quantity, :unit, :low_quantity_threshold]
)

App.add_item!(plan, "Race shoes",
  actor: actor,
  key: "race_shoes",
  type: "running_shoes",
  starting_quantity: 80,
  unit: "km",
  low_at: 50
)

App.add_event_type!(plan, "Run completed",
  actor: actor,
  key: "run_completed",
  required_links: ["shoes"],
  payload: %{required: ["amount", "unit"]},
  effects: [
    App.subtract_quantity(item: "shoes", quantity: "payload.amount", unit: "payload.unit")
  ]
)

App.add_track!(plan, "Long run",
  actor: actor,
  key: "long_run",
  event: "run_completed",
  schedule: App.every_week(times: 1, on: [:sunday]),
  target: App.fixed(20, "km"),
  records: App.amount("km")
)

App.add_track!(plan, "Tempo run",
  actor: actor,
  key: "tempo_run",
  event: "run_completed",
  schedule: App.every_week(times: 1, on: [:thursday]),
  target: App.fixed(8, "km"),
  records: App.amount("km")
)

App.add_track!(plan, "Intervals",
  actor: actor,
  key: "intervals",
  event: "run_completed",
  schedule: App.every_week(times: 1, on: [:tuesday]),
  target: App.fixed(6, "km"),
  records: App.amount("km")
)

App.add_track!(plan, "Easy run",
  actor: actor,
  key: "easy_run",
  event: "run_completed",
  schedule: App.every_week(times: 2, on: [:wednesday, :saturday]),
  target: App.fixed(5, "km"),
  records: App.amount("km")
)

Story.show_plan_summary!(story, plan)

# -----------------------------------------------------------------------------
# Layer 1 — A couple of weeks of training (projection, runs, shoe wear)
# -----------------------------------------------------------------------------

sunday = App.project_today!(plan, actor: actor, date: ~D[2026-06-28])
Story.show_projection!(story, sunday)

App.log_event!(plan,
  actor: actor,
  event: "run_completed",
  track: "long_run",
  on: ~D[2026-06-28],
  summary: "Long run 20 km",
  links: %{shoes: "race_shoes"},
  payload: %{amount: 20, unit: "km"}
)

Story.show_item_state!(story, plan, "race_shoes")

thursday = App.project_today!(plan, actor: actor, date: ~D[2026-07-02])
Story.show_projection!(story, thursday)

App.log_event!(plan,
  actor: actor,
  event: "run_completed",
  track: "tempo_run",
  on: ~D[2026-07-02],
  summary: "Tempo run 8 km",
  links: %{shoes: "race_shoes"},
  payload: %{amount: 8, unit: "km"}
)

App.log_event!(plan,
  actor: actor,
  event: "run_completed",
  track: "long_run",
  on: ~D[2026-07-05],
  summary: "Long run 18 km",
  links: %{shoes: "race_shoes"},
  payload: %{amount: 18, unit: "km"}
)

Story.show_journal!(story, plan)
Story.show_item_state!(story, plan, "race_shoes")

Story.show_review!(story, plan, on: ~D[2026-07-06])

# -----------------------------------------------------------------------------
# Layer 1 — Planned time off (runs today)
#
# Holidays are plan-scoped windows, not journal events. During a fully-off
# window, projection keeps the scheduled work visible as on hold rather than
# marking it missed.
# -----------------------------------------------------------------------------

App.add_time_off!(plan,
  actor: actor,
  key: "summer_holiday",
  kind: :holiday,
  reason: "Summer holiday",
  from: ~D[2026-08-10],
  to: ~D[2026-08-23],
  availability: :fully_off
)

mid_holiday = App.project_today!(plan, actor: actor, date: ~D[2026-08-16])
Story.show_projection!(story, mid_holiday)

# =============================================================================
# Layer 2 (Customization) now runs. Layer 3 (Adaptation) below remains INTENDED
# product flow, written as comments so the script stays runnable.
# =============================================================================

# -----------------------------------------------------------------------------
# LAYER 2 — Baseline customization (RUNS today)
#
# One-time plan generation derives training paces from the 5k baseline and bakes
# them into each track's guidance as auditable static structure. This is not a
# hot-loop computation — it runs once, at customization time, and writes ordinary
# plan data. Projection later reads that data; it never re-derives it. That is
# what keeps customization (Layer 2) separate from projection-time adaptation
# (Layer 3).
#
# With a 25:00 5k (300 s/km):
#   easy      300 + 75 = 6:15 /km
#   marathon  300 + 40 = 5:40 /km   (sub-4:00 race pace)
#   tempo     300 + 25 = 5:25 /km
#   interval  300 -  5 = 4:55 /km
# -----------------------------------------------------------------------------

customization =
  Story.customize_plan!(story, plan,
    from_baseline: "time_trial",
    derive: %{
      easy_pace: {:secs_per_km, :five_k, plus: 75},
      marathon_pace: {:secs_per_km, :five_k, plus: 40},
      tempo_pace: {:secs_per_km, :five_k, plus: 25},
      interval_pace: {:secs_per_km, :five_k, minus: 5}
    },
    apply_to: %{
      "easy_run" => :easy_pace,
      "long_run" => :easy_pace,
      "tempo_run" => :tempo_pace,
      "intervals" => :interval_pace
    }
  )

Story.show_customization!(story, plan, customization)

# The derived paces now ride on the tracks as guidance. Re-projecting a week
# shows the plan with its baseline-derived structure in place, ready for Layer 3
# adaptation to respond to what actually happens.
mid_week = App.project_today!(plan, actor: actor, date: ~D[2026-07-09])
Story.show_projection!(story, mid_week)

# -----------------------------------------------------------------------------
# LAYER 3 — Adaptation (INTENDED; not yet implemented)
#
# This is the layer that separates a great plan from a static schedule. It
# needs a marathon adaptation evaluator that, on each projection, receives
# recent history + life events + time-off windows + derived training load, and
# returns today's work plus proposals.
#
#   - Derived proposals apply inside projection (no write): deload, shift,
#     swap to rest / cross-train.
#   - Committed proposals surface for the user to accept (core write): extend
#     the plan, change the race date.
#
# The first real evaluator dependency appears here: adaptation CONSUMES
# derived metrics (recent load, consecutive build weeks), so a derived-metric
# evaluator must run before the adaptation evaluator. That cross-evaluator
# dependency is what forces the capability graph.
#
# Beans: improve-ash-c2xh (marathon evaluator), improve-ash-q6p8 (derived
# adaptation), improve-ash-syws (committed adaptation), and the graph beans
# improve-ash-h81d / improve-ash-44nx / improve-ash-38rj.
# -----------------------------------------------------------------------------

# --- 3a. Missed session ------------------------------------------------------
# Runner skips Tuesday intervals. Thursday should NOT stack the missed quality
# onto the tempo; it resumes with the scheduled work and drops the miss.
#
#   thursday = App.project_today!(plan, actor: actor, date: ~D[2026-07-09])
#   Story.show_projection!(story, thursday)
#
# Intended adaptation output for that projection:
#   todays_work : tempo run (as scheduled)
#   proposals   : shift_session :missed_quality   (derived, approval: false)
#                 "Missed Tuesday intervals dropped, not stacked onto today."

# --- 3b. Illness -------------------------------------------------------------
# Runner logs a 3-day fever ending yesterday. First day back, the neck rule
# says full rest; the week deloads; a plan extension is proposed.
#
#   App.log_life_event!(plan,
#     type: :illness,
#     from: ~D[2026-07-06], to: ~D[2026-07-08],
#     symptoms: :fever,
#     actor: actor
#   )
#
#   first_day_back = App.project_today!(plan, actor: actor, date: ~D[2026-07-09])
#   Story.show_projection!(story, first_day_back)
#
# Intended adaptation output:
#   todays_work : rest
#                 "1 day past a 3-day fever; full rest per the neck rule."
#   proposals   : deload_week 50%                (derived, approval: false)
#                 shift_session :missed_quality   (derived, approval: false)
#                 extend_plan 1 week              (committed, approval: true)
#                 "Illness may delay race readiness; consider extending."

# --- 3c. Injury --------------------------------------------------------------
# Runner flags a calf strain. Today's tempo becomes rest / cross-train;
# running pauses until the flag clears.
#
#   App.log_life_event!(plan, type: :injury, area: :calf, severity: 2, actor: actor)
#
#   today = App.project_today!(plan, actor: actor, date: ~D[2026-07-16])
#   Story.show_projection!(story, today)
#
# Intended adaptation output:
#   todays_work : cross_train (rest from running)
#   proposals   : deload_week 50%            (derived)
#                 extend_plan 1-2 weeks      (committed, approval: true)

# --- 3d. Holiday (a 2-week time-off window) ----------------------------------
# A holiday is already declared above as a real plan-scoped time-off window
# (see "Planned: Time-Off Windows" in notes/improve-model-and-extension-points.md).
# The UI will eventually block the dates on the calendar; projection already
# keeps scheduled work on hold instead of missed; adaptation still needs to
# reason about the gap.
#
# The first day back, adaptation proposes a reduced re-entry run (derived) and
# a plan edit to absorb the two-week gap (committed):
#
#   first_day_back = App.project_today!(plan, actor: actor, date: ~D[2026-08-24])
#   Story.show_projection!(story, first_day_back)
#
# Intended adaptation output:
#   todays_work : easy run (short re-entry)
#                 "First run back after 2 weeks off; keep it easy and short."
#   proposals   : rebuild_week (derived, approval: false)
#                 extend_plan (committed, approval: true)
#                 "Absorb the 2-week gap by extending toward the race."
#
# Hard edge: Berlin (2026-10-04) is a fixed external event, so extend_plan may
# be impossible. When the deadline cannot move, the evaluator shifts to
# compress-the-taper or adjust-the-goal (sub-4:00 -> finish) instead. The race
# date is just the plan's `until:`; whether it can move is the evaluator's call.

# --- Committed adaptation surfaces in review ---------------------------------
# The extend_plan proposals are committed adaptations: they mutate plan
# structure, so they go through a core action and need the user's approval.
# Review is where they are presented plainly.
#
#   Story.show_review!(story, plan, on: ~D[2026-07-09])
#   # => suggested change: "Extend your plan by 1 week to absorb the illness."
#   # => user accepts:
#   App.adjust_plan!(plan, extend_by_weeks: 1, actor: actor)
