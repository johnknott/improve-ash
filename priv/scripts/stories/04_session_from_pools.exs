alias Improve.App
alias Improve.Stories, as: Story

story =
  Story.begin!("session_from_pools", reset?: true)
  |> Story.user!("John", email: "story+session-from-pools@example.test")

actor = story.user

plan =
  App.create_plan!("Practice starter plan",
    actor: actor,
    intention: "Build a consistent focused practice habit",
    from: ~D[2026-06-22],
    until: ~D[2026-07-23]
  )

App.add_event_type!(plan, "Practice logged",
  actor: actor,
  key: "practice_logged",
  required_links: ["item"],
  payload: %{
    required: ["rounds", "duration_minutes", "effort"],
    properties: %{
      rounds: %{type: "integer"},
      duration_minutes: %{type: "integer"},
      effort: %{type: "string"},
      note: %{type: "string"}
    }
  }
)

App.add_item_type!(plan, "Practice item", actor: actor, key: "practice_item")
App.add_item!(plan, "Piano scales", actor: actor, key: "piano_scales", type: "practice_item")
App.add_item!(plan, "Sight reading", actor: actor, key: "sight_reading", type: "practice_item")
App.add_item!(plan, "Ear training", actor: actor, key: "ear_training", type: "practice_item")
App.add_item!(plan, "Rhythm drills", actor: actor, key: "rhythm_drills", type: "practice_item")
App.add_item!(plan, "Improvisation", actor: actor, key: "improvisation", type: "practice_item")

App.add_pool!(plan, "Technique choices",
  actor: actor,
  key: "technique",
  items: ["piano_scales", "sight_reading"]
)

App.add_pool!(plan, "Listening choices",
  actor: actor,
  key: "listening",
  items: ["ear_training", "rhythm_drills"]
)

suggestion =
  App.adaptive(fields: [:rounds, :duration_minutes], effort: :effort, review: :weekly)

App.add_session!(plan, "Focused practice",
  actor: actor,
  key: "focused_practice",
  schedule: App.every_week(times: 2, on: [:monday, :thursday]),
  slots: [
    App.choose(2,
      from: "technique",
      suggest: suggestion,
      start_with: %{rounds: 2, duration_minutes: 10, effort: "easy"}
    ),
    App.choose(2,
      from: "listening",
      suggest: suggestion,
      start_with: %{rounds: 2, duration_minutes: 8, effort: "easy"}
    )
  ]
)

Story.show_plan_summary!(story, plan)

today = App.project_today!(plan, actor: actor, date: ~D[2026-06-22])
Story.show_projection!(story, today)

session = App.start_session!(today, "focused_practice", actor: actor)
Story.show_session!(story, session)

App.log_session_slot!(session,
  actor: actor,
  slot: "technique",
  item: "piano_scales",
  event: "practice_logged",
  payload: %{rounds: 2, duration_minutes: 12, effort: "steady"},
  note: "Felt focused"
)

App.log_session_slot!(session,
  actor: actor,
  slot: "technique",
  recommended: "sight_reading",
  actual: "improvisation",
  event: "practice_logged",
  payload: %{rounds: 3, duration_minutes: 10, effort: "playful"},
  note: "Swapped to keep momentum"
)

Story.show_session_results!(story, session)
Story.show_journal!(story, plan)
Story.show_ai_today_context!(story, plan, on: ~D[2026-06-22])
Story.show_ai_recent_journal!(story, plan, limit: 10)
