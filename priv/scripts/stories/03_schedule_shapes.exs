# Story: the calendar shapes Improve can project.
#
# This shows how scheduled tracks appear on the right days: daily, selected
# weekdays, every few days, every few weeks, and monthly. It also keeps the two
# harder V1-deferred schedule ideas visible, so unsupported shapes fail loudly
# with useful diagnostics instead of pretending to work.

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

App.add_track!(plan, "Every two weeks",
  actor: actor,
  key: "every_two_weeks",
  event: "check_in",
  schedule: App.every_n_weeks(2, on: [:friday]),
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

App.add_track!(plan, "After completion check",
  actor: actor,
  key: "after_completion_check",
  event: "check_in",
  schedule: App.after_completion(days: 2),
  target: fixed(1, "check"),
  records: number("check")
)

App.add_track!(plan, "Custom check",
  actor: actor,
  key: "custom_check",
  event: "check_in",
  schedule: App.custom("when the weather is good"),
  target: fixed(1, "check"),
  records: number("check")
)

Story.show_plan_summary!(story, plan)

today = App.project_today!(plan, actor: actor, date: ~D[2026-06-26])
Story.show_projection!(story, today)

if today.diagnostics != [] do
  Story.show_ai_today_context!(story, plan, on: ~D[2026-06-26])
end

fortnightly = App.project_today!(plan, actor: actor, date: ~D[2026-07-10])
Story.show_projection!(story, fortnightly)

monthly = App.project_today!(plan, actor: actor, date: ~D[2026-07-15])
Story.show_projection!(story, monthly)
