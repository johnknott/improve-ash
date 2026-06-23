alias Improve.App
alias Improve.Stories, as: Story

story =
  Story.begin!("gym_session_basic", reset?: true)
  |> Story.user!("John", email: "story+gym-session-basic@example.test")

actor = story.user

plan =
  App.create_plan!("Gym starter plan",
    actor: actor,
    intention: "Build a consistent upper body routine",
    from: ~D[2026-06-22],
    until: ~D[2026-07-23]
  )

App.add_event_type!(plan, "Exercise performed",
  actor: actor,
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

App.add_exercise!(plan, "Chest Press", actor: actor, key: "chest_press")
App.add_exercise!(plan, "Shoulder Press", actor: actor, key: "shoulder_press")
App.add_exercise!(plan, "Lat Pulldown", actor: actor, key: "lat_pulldown")
App.add_exercise!(plan, "Seated Row", actor: actor, key: "seated_row")
App.add_exercise!(plan, "Cable Fly", actor: actor, key: "cable_fly")

App.add_pool!(plan, "Push exercises",
  actor: actor,
  key: "push",
  items: ["chest_press", "shoulder_press"]
)

App.add_pool!(plan, "Pull exercises",
  actor: actor,
  key: "pull",
  items: ["lat_pulldown", "seated_row"]
)

App.add_session!(plan, "Upper body gym visit",
  actor: actor,
  key: "upper_body",
  schedule: App.every_week(times: 2, on: [:monday, :thursday]),
  slots: [
    App.choose(2, from: "push"),
    App.choose(2, from: "pull")
  ]
)

Story.show_plan_summary!(story, plan)

today = App.project_today!(plan, actor: actor, date: ~D[2026-06-22])
Story.show_projection!(story, today)

session = App.start_session!(today, "upper_body", actor: actor)
Story.show_session!(story, session)

App.log_session_slot!(session,
  actor: actor,
  slot: "push",
  item: "chest_press",
  event: "exercise_performed",
  payload: %{sets: 3, reps: 10, load: 45, load_unit: "kg", rpe: 8},
  note: "Felt solid"
)

App.log_session_slot!(session,
  actor: actor,
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
