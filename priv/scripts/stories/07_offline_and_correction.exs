# Story: the journal stays trustworthy when reality is messy.
#
# This demonstrates two important safety flows. First, a mistaken event is
# corrected without deleting history. Then offline submissions are accepted,
# deduplicated, or rejected in a way that protects the plan from stale client
# data.

alias Improve.App
alias Improve.Stories, as: Story

story =
  Story.begin!("offline_duplicate_and_stale", reset?: true)
  |> Story.user!("John", email: "story+offline-duplicate-and-stale@example.test")

actor = story.user

correction_plan =
  App.create_plan!("Correction history plan",
    actor: actor,
    intention: "Correct mistakes without losing journal history",
    from: ~D[2026-06-22],
    until: ~D[2026-09-14]
  )

App.add_item_type!(correction_plan, "Supply container",
  actor: actor,
  key: "supply_container",
  facts: [:starting_quantity, :unit]
)

App.add_item!(correction_plan, "Workshop bin",
  actor: actor,
  key: "workshop_bin",
  type: "supply_container",
  starting_quantity: 20,
  unit: "uses"
)

App.add_event_type!(correction_plan, "Use recorded",
  actor: actor,
  key: "use_recorded",
  required_links: ["container"],
  payload: %{required: ["amount", "unit"]},
  effects: [
    App.subtract_quantity(item: "container", quantity: "payload.amount", unit: "payload.unit")
  ]
)

original =
  App.log_event!(correction_plan,
    actor: actor,
    event: "use_recorded",
    on: ~D[2026-06-22],
    summary: "Use recorded from Workshop bin",
    links: %{container: "workshop_bin"},
    payload: %{amount: 17, unit: "uses"}
  )

correction =
  App.correct_event!(original,
    actor: actor,
    corrected_at: ~U[2026-06-22 21:00:00Z],
    reason: "Amount was entered incorrectly",
    replacement: [
      event: "use_recorded",
      effective_at: ~U[2026-06-22 20:00:00Z],
      summary: "Corrected use from Workshop bin",
      links: %{container: "workshop_bin"},
      payload: %{amount: 12, unit: "uses"}
    ]
  )

Story.show_correction_result!(story, correction)
Story.show_journal!(story, correction_plan)
Story.show_item_state!(story, correction_plan, "workshop_bin")

plan =
  App.create_plan!("Offline resilience plan",
    actor: actor,
    intention: "Accept offline logs safely without duplicating or overwriting stale work",
    from: ~D[2026-06-22],
    until: ~D[2026-07-23]
  )

App.add_event_type!(plan, "Pages read",
  actor: actor,
  key: "pages_read",
  payload: %{required: ["pages"]}
)

App.add_track!(plan, "Read 20 pages",
  actor: actor,
  key: "daily_reading",
  event: "pages_read",
  schedule: App.every_day(),
  target: %{
    quantity: 20,
    unit: "pages",
    quantity_path: "payload.pages",
    summary_template: "Read %{quantity} %{unit}"
  }
)

App.add_event_type!(plan, "Practice logged",
  actor: actor,
  key: "practice_logged",
  required_links: ["item"],
  payload: %{required: ["rounds", "duration_minutes"]}
)

App.add_item_type!(plan, "Practice item", actor: actor, key: "practice_item")
App.add_item!(plan, "Piano scales", actor: actor, key: "piano_scales", type: "practice_item")
App.add_item!(plan, "Ear training", actor: actor, key: "ear_training", type: "practice_item")

App.add_pool!(plan, "Technique choices", actor: actor, key: "technique", items: ["piano_scales"])
App.add_pool!(plan, "Listening choices", actor: actor, key: "listening", items: ["ear_training"])

App.add_session!(plan, "Focused practice",
  actor: actor,
  key: "focused_practice",
  schedule: App.every_week(times: 1, on: [:monday]),
  slots: [
    App.choose(1, from: "technique"),
    App.choose(1, from: "listening")
  ]
)

today = App.project_today!(plan, actor: actor, date: ~D[2026-06-22])
session = App.start_session!(today, "focused_practice", actor: actor)

reading =
  App.offline_event(plan,
    actor: actor,
    event: "pages_read",
    track: "daily_reading",
    on: ~D[2026-06-22],
    summary: "Read 20 pages offline",
    payload: %{pages: 20, note: "Queued while offline"},
    operation: "offline-reading-001",
    client_event_id: "offline-reading-001-event",
    idempotency_key: "offline-reading-001-key"
  )

logged_slot =
  App.log_session_slot!(session,
    actor: actor,
    slot: "technique",
    item: "piano_scales",
    event: "practice_logged",
    payload: %{rounds: 2, duration_minutes: 12},
    note: "Logged before offline retry arrived"
  )
  |> Map.fetch!(:slot_result)

stale_slot =
  App.offline_event(plan,
    actor: actor,
    event: "practice_logged",
    on: ~D[2026-06-22],
    summary: "Offline practice retry",
    links: %{item: "piano_scales"},
    payload: %{rounds: 2, duration_minutes: 12},
    session_occurrence_id: session.session_occurrence.id,
    slot_result_id: logged_slot.id,
    operation: "offline-slot-001",
    client_event_id: "offline-slot-001-event",
    idempotency_key: "offline-slot-001-key"
  )

results = App.submit_offline_events!([reading, reading, stale_slot], actor: actor)

Story.show_offline_results!(story, results)
Story.show_journal!(story, plan)
Story.show_ai_today_context!(story, plan, on: ~D[2026-06-22])
