alias Improve.Stories, as: Story

story =
  Story.begin!("hybrid_today", reset?: true)
  |> Story.user!("John", email: "story+hybrid-today@example.test")

plan =
  Story.create_plan!(story, "Hybrid today plan",
    intention: "See daily goals and gym sessions together",
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

before = Story.project_today!(story, plan, on: ~D[2026-06-22])
Story.show_projection!(story, before)

Story.log_direct_goal!(story, before,
  goal: "daily_reading",
  payload: %{pages: 25, note: "Read before breakfast"}
)

session = Story.start_session!(story, before, "upper_body")

Story.log_slot!(story, session,
  slot: "push",
  item: "chest_press",
  event: "exercise_performed",
  payload: %{sets: 3, reps: 10},
  note: "First exercise done"
)

after_projection = Story.project_today!(story, plan, on: ~D[2026-06-22])
Story.show_projection!(story, after_projection)
Story.show_session_results!(story, session)
Story.show_journal!(story, plan)
Story.show_ai_today_context!(story, plan, on: ~D[2026-06-22])
