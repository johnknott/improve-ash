alias Improve.App
alias Improve.Stories, as: Story

story =
  Story.begin!("offline_duplicate_and_stale", reset?: true)
  |> Story.user!("John", email: "story+offline-duplicate-and-stale@example.test")

actor = story.user

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

App.add_event_type!(plan, "Exercise performed",
  actor: actor,
  key: "exercise_performed",
  required_links: ["exercise"],
  payload: %{required: ["sets", "reps"]}
)

App.add_item_type!(plan, "Exercise", actor: actor, key: "exercise")
App.add_item!(plan, "Chest Press", actor: actor, key: "chest_press", type: "exercise")
App.add_item!(plan, "Lat Pulldown", actor: actor, key: "lat_pulldown", type: "exercise")

App.add_pool!(plan, "Push exercises", actor: actor, key: "push", items: ["chest_press"])
App.add_pool!(plan, "Pull exercises", actor: actor, key: "pull", items: ["lat_pulldown"])

App.add_session!(plan, "Upper body gym visit",
  actor: actor,
  key: "upper_body",
  schedule: App.every_week(times: 1, on: [:monday]),
  slots: [
    App.choose(1, from: "push"),
    App.choose(1, from: "pull")
  ]
)

today = App.project_today!(plan, actor: actor, date: ~D[2026-06-22])
session = App.start_session!(today, "upper_body", actor: actor)

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
    slot: "push",
    item: "chest_press",
    event: "exercise_performed",
    payload: %{sets: 3, reps: 10},
    note: "Logged before offline retry arrived"
  )
  |> Map.fetch!(:slot_result)

stale_slot =
  App.offline_event(plan,
    actor: actor,
    event: "exercise_performed",
    on: ~D[2026-06-22],
    summary: "Offline chest press retry",
    links: %{exercise: "chest_press"},
    payload: %{sets: 3, reps: 10},
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
