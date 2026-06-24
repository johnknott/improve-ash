alias Improve.App
alias Improve.Stories, as: Story

story =
  Story.begin!("hybrid_today", reset?: true)
  |> Story.user!("John", email: "story+hybrid-today@example.test")

actor = story.user

plan =
  App.create_plan!("Hybrid today plan",
    actor: actor,
    intention: "See daily tracks and gym sessions together",
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

before = App.project_today!(plan, actor: actor, date: ~D[2026-06-22])
Story.show_projection!(story, before)

App.log_track!(before,
  actor: actor,
  track: "daily_reading",
  payload: %{pages: 25, note: "Read before breakfast"}
)

session = App.start_session!(before, "upper_body", actor: actor)

App.log_session_slot!(session,
  actor: actor,
  slot: "push",
  item: "chest_press",
  event: "exercise_performed",
  payload: %{sets: 3, reps: 10},
  note: "First exercise done"
)

after_projection = App.project_today!(plan, actor: actor, date: ~D[2026-06-22])
Story.show_projection!(story, after_projection)
Story.show_session_results!(story, session)
Story.show_journal!(story, plan)
Story.show_ai_today_context!(story, plan, on: ~D[2026-06-22])
