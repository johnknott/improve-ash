alias Improve.App
alias Improve.Stories, as: Story

story =
  Story.begin!("adaptive_item_work", reset?: true)
  |> Story.user!("John", email: "story+adaptive-item-work@example.test")

actor = story.user

plan =
  App.create_plan!("Adaptive practice plan",
    actor: actor,
    intention: "Suggest the next useful work for each item",
    from: ~D[2026-06-22],
    until: ~D[2026-07-23]
  )

App.add_event_type!(plan, "Practice logged",
  actor: actor,
  key: "practice_logged",
  required_links: ["item"],
  payload: %{required: ["rounds", "duration_minutes", "effort"]}
)

App.add_item_type!(plan, "Practice item", actor: actor, key: "practice_item")
App.add_item!(plan, "Piano scales", actor: actor, key: "piano_scales", type: "practice_item")
App.add_item!(plan, "Sight reading", actor: actor, key: "sight_reading", type: "practice_item")

App.add_pool!(plan, "Technique choices",
  actor: actor,
  key: "technique",
  items: ["piano_scales", "sight_reading"]
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
    )
  ]
)

App.log_event!(plan,
  actor: actor,
  event: "practice_logged",
  on: ~D[2026-06-21],
  summary: "Piano scales performed",
  links: %{item: "piano_scales"},
  payload: %{rounds: 3, duration_minutes: 12, effort: "steady"}
)

today = App.project_today!(plan, actor: actor, date: ~D[2026-06-22])
Story.show_projection!(story, today)
Story.show_ai_today_context!(story, plan, on: ~D[2026-06-22])
