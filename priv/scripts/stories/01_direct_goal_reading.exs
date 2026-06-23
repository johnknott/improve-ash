alias Improve.App
alias Improve.Stories, as: Story

story =
  Story.begin!("direct_goal_reading", reset?: true)
  |> Story.user!("John", email: "story+direct-goal-reading@example.test")

actor = story.user

plan =
  App.create_plan!("Read more consistently",
    actor: actor,
    intention: "Read a little every day",
    from: ~D[2026-06-23],
    until: ~D[2026-07-23]
  )

App.add_event_type!(plan, "Pages read",
  actor: actor,
  key: "pages_read",
  payload: %{
    required: ["pages"],
    properties: %{
      pages: %{type: "integer"},
      note: %{type: "string"}
    }
  }
)

App.add_direct_goal!(plan, "Read 20 pages",
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

Story.show_plan_summary!(story, plan)

today = App.project_today!(plan, actor: actor, date: ~D[2026-06-23])
Story.show_projection!(story, today)

App.log_direct_goal!(today,
  actor: actor,
  goal: "daily_reading",
  payload: %{pages: 25, note: "Read before bed"}
)

Story.show_journal!(story, plan)
Story.show_ai_plan_summary!(story, plan)
Story.show_ai_today_context!(story, plan, on: ~D[2026-06-23])
Story.show_ai_recent_journal!(story, plan, limit: 10)
