alias Improve.Stories, as: Story

story =
  Story.begin!("direct_goal_reading", reset?: true)
  |> Story.user!("John", email: "story+direct-goal-reading@example.test")

plan =
  Story.create_plan!(story, "Read more consistently",
    intention: "Read a little every day",
    from: ~D[2026-06-23],
    until: ~D[2026-07-23]
  )

Story.add_event_type!(story, plan, "Pages read",
  key: "pages_read",
  payload: %{
    required: ["pages"],
    properties: %{
      pages: %{type: "integer"},
      note: %{type: "string"}
    }
  }
)

Story.add_direct_goal!(story, plan, "Read 20 pages",
  key: "daily_reading",
  event: "pages_read",
  schedule: Story.every_day(),
  target: %{pages: 20}
)

Story.show_plan_summary!(story, plan)

today = Story.project_today!(story, plan, on: ~D[2026-06-23])
Story.show_projection!(story, today)

Story.log_direct_goal!(story, today,
  goal: "daily_reading",
  event: "pages_read",
  payload: %{pages: 25, note: "Read before bed"},
  quantity: 25,
  unit: "pages",
  note: "Read before bed"
)

Story.show_journal!(story, plan)
Story.show_ai_plan_summary!(story, plan)
Story.show_ai_today_context!(story, plan, on: ~D[2026-06-23])
Story.show_ai_recent_journal!(story, plan, limit: 10)
