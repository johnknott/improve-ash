alias Improve.App
alias Improve.Stories, as: Story
import Improve.App, only: [fixed: 2, number: 1]

story =
  Story.begin!("schedule_shapes", reset?: true)
  |> Story.user!("John", email: "story+schedule-shapes@example.test")

actor = story.user

plan =
  App.create_plan!("Try schedule shapes",
    actor: actor,
    intention: "See which schedule shapes project today",
    from: ~D[2026-06-23],
    until: ~D[2026-07-23]
  )

App.add_event_type!(plan, "Check in",
  actor: actor,
  key: "check_in",
  payload: %{
    required: ["amount"],
    properties: %{amount: %{type: "integer"}}
  }
)

App.add_track!(plan, "Daily check",
  actor: actor,
  key: "daily_check",
  event: "check_in",
  schedule: App.every_day(),
  target: fixed(1, "check"),
  records: number("check")
)

App.add_track!(plan, "Weekday check",
  actor: actor,
  key: "weekday_check",
  event: "check_in",
  schedule: App.selected_weekdays([:monday, :wednesday, :friday]),
  target: fixed(1, "check"),
  records: number("check")
)

App.add_track!(plan, "Every three days",
  actor: actor,
  key: "every_three_days",
  event: "check_in",
  schedule: App.every_n_days(3),
  target: fixed(1, "check"),
  records: number("check")
)

App.add_track!(plan, "Monthly check",
  actor: actor,
  key: "monthly_check",
  event: "check_in",
  schedule: App.monthly(day: 15),
  target: fixed(1, "check"),
  records: number("check")
)

Story.show_plan_summary!(story, plan)

today = App.project_today!(plan, actor: actor, date: ~D[2026-06-26])
Story.show_projection!(story, today)

if today.diagnostics != [] do
  Story.show_ai_today_context!(story, plan, on: ~D[2026-06-26])
end
