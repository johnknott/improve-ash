alias Improve.Stories, as: Story

story =
  Story.begin!("gym_session_basic", reset?: true)
  |> Story.user!("John", email: "story+gym-session-basic@example.test")

plan =
  Story.create_plan!(story, "Gym starter plan",
    intention: "Build a consistent upper body routine",
    from: ~D[2026-06-22],
    until: ~D[2026-07-23]
  )

Story.add_event_type!(story, plan, "Exercise performed",
  key: "exercise_performed",
  required_links: ["exercise"],
  payload: %{
    required: ["sets", "reps", "load", "load_unit"],
    properties: %{
      sets: %{type: "integer"},
      reps: %{type: "integer"},
      load: %{type: "number"},
      load_unit: %{type: "string"},
      rpe: %{type: "integer"},
      note: %{type: "string"}
    }
  }
)

Story.add_exercise!(story, plan, "Chest Press", key: "chest_press")
Story.add_exercise!(story, plan, "Shoulder Press", key: "shoulder_press")
Story.add_exercise!(story, plan, "Lat Pulldown", key: "lat_pulldown")
Story.add_exercise!(story, plan, "Seated Row", key: "seated_row")
Story.add_exercise!(story, plan, "Cable Fly", key: "cable_fly")

Story.add_pool!(story, plan, "Push exercises",
  key: "push",
  items: ["chest_press", "shoulder_press"]
)

Story.add_pool!(story, plan, "Pull exercises",
  key: "pull",
  items: ["lat_pulldown", "seated_row"]
)

Story.add_session!(story, plan, "Upper body gym visit",
  key: "upper_body",
  schedule: Story.every_week(times: 2, on: [:monday, :thursday]),
  slots: [
    Story.choose(2, from: "push"),
    Story.choose(2, from: "pull")
  ]
)

Story.show_plan_summary!(story, plan)

today = Story.project_today!(story, plan, on: ~D[2026-06-22])
Story.show_projection!(story, today)

session = Story.start_session!(story, today, "upper_body")
Story.show_session!(story, session)

Story.log_slot!(story, session,
  slot: "push",
  item: "chest_press",
  event: "exercise_performed",
  payload: %{sets: 3, reps: 10, load: 45, load_unit: "kg", rpe: 8},
  note: "Felt solid"
)

Story.log_slot!(story, session,
  slot: "push",
  recommended: "shoulder_press",
  actual: "cable_fly",
  event: "exercise_performed",
  payload: %{sets: 3, reps: 12, load: 20, load_unit: "kg", rpe: 7},
  note: "Shoulder press station was busy"
)

Story.show_session_results!(story, session)
Story.show_journal!(story, plan)
Story.show_ai_today_context!(story, plan, on: ~D[2026-06-22])
Story.show_ai_recent_journal!(story, plan, limit: 10)
