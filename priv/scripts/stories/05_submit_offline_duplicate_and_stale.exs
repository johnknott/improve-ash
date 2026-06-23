alias Improve.Stories, as: Story

story =
  Story.begin!("offline_duplicate_and_stale", reset?: true)
  |> Story.user!("John", email: "story+offline-duplicate-and-stale@example.test")

plan =
  Story.create_plan!(story, "Offline resilience plan",
    intention: "Accept offline logs safely without duplicating or overwriting stale work",
    from: ~D[2026-06-22],
    until: ~D[2026-07-23]
  )

Story.add_event_type!(story, plan, "Pages read",
  key: "pages_read",
  payload: %{required: ["pages"]}
)

Story.add_direct_goal!(story, plan, "Read 20 pages",
  key: "daily_reading",
  event: "pages_read",
  schedule: Story.every_day(),
  target: %{
    quantity: 20,
    unit: "pages",
    quantity_path: "payload.pages",
    summary_template: "Read %{quantity} %{unit}"
  }
)

Story.add_event_type!(story, plan, "Exercise performed",
  key: "exercise_performed",
  required_links: ["exercise"],
  payload: %{required: ["sets", "reps"]}
)

Story.add_exercise!(story, plan, "Chest Press", key: "chest_press")
Story.add_exercise!(story, plan, "Lat Pulldown", key: "lat_pulldown")

Story.add_pool!(story, plan, "Push exercises", key: "push", items: ["chest_press"])
Story.add_pool!(story, plan, "Pull exercises", key: "pull", items: ["lat_pulldown"])

Story.add_session!(story, plan, "Upper body gym visit",
  key: "upper_body",
  schedule: Story.every_week(times: 1, on: [:monday]),
  slots: [
    Story.choose(1, from: "push"),
    Story.choose(1, from: "pull")
  ]
)

today = Story.project_today!(story, plan, on: ~D[2026-06-22])
session = Story.start_session!(story, today, "upper_body")

reading =
  Story.offline_event(story, plan,
    event: "pages_read",
    goal: "daily_reading",
    on: ~D[2026-06-22],
    summary: "Read 20 pages offline",
    payload: %{pages: 20, note: "Queued while offline"},
    operation: "offline-reading-001",
    client_event_id: "offline-reading-001-event",
    idempotency_key: "offline-reading-001-key"
  )

logged_slot =
  Story.log_slot!(story, session,
    slot: "push",
    item: "chest_press",
    event: "exercise_performed",
    payload: %{sets: 3, reps: 10},
    note: "Logged before offline retry arrived"
  )
  |> Map.fetch!(:slot_result)

stale_slot =
  Story.offline_event(story, plan,
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

results = Story.submit_offline_events!(story, [reading, reading, stale_slot])

Story.show_offline_results!(story, results)
Story.show_journal!(story, plan)
Story.show_ai_today_context!(story, plan, on: ~D[2026-06-22])
