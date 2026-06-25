# Story: the different ways a track can know whether it is done.
#
# This demonstrates the target vocabulary a normal user might expect: fixed
# amounts, metrics, checklists, weekly totals, gradual progressions, and
# adaptive practice fields. The point is to show that projection can now say
# what is planned, what is complete, and what progress means for each shape.

alias Improve.App
alias Improve.Stories, as: Story

import Improve.App,
  only: [
    adaptive: 1,
    amount: 1,
    checklist: 1,
    fields: 1,
    fixed: 2,
    metric: 2,
    number: 1,
    period_total: 3,
    progression: 3
  ]

story =
  Story.begin!("track_target_types", reset?: true)
  |> Story.user!("John", email: "story+track-target-types@example.test")

actor = story.user

plan =
  App.create_plan!("Try track targets",
    actor: actor,
    intention: "See the target vocabulary the backend understands",
    from: ~D[2026-06-23],
    until: ~D[2026-07-23]
  )

App.add_track!(plan, "Reading",
  actor: actor,
  key: "reading",
  schedule: App.every_day(),
  target: fixed(20, "pages"),
  records: number("pages")
)

App.add_track!(plan, "Bodyweight",
  actor: actor,
  key: "bodyweight",
  schedule: App.every_day(),
  target: metric("Bodyweight", unit: "kg"),
  records: amount("kg")
)

App.add_track!(plan, "Evening reset",
  actor: actor,
  key: "evening_reset",
  schedule: App.every_day(),
  target: checklist(["Tidy room", "Brush teeth"])
)

App.add_track!(plan, "Weekly pages",
  actor: actor,
  key: "weekly_pages",
  schedule: App.every_day(),
  target: period_total(100, "pages", per: :week),
  records: number("pages")
)

App.add_track!(plan, "Daily steps",
  actor: actor,
  key: "daily_steps",
  schedule: App.every_day(),
  target: progression(1_000, 10_000, unit: "steps", shape: :linear),
  records: number("steps")
)

App.add_track!(plan, "Practice item",
  actor: actor,
  key: "practice_item",
  schedule: App.every_day(),
  target: adaptive(fields: [:sets, :reps, :load], effort: :effort, review: :weekly),
  records: fields([:sets, :reps, :load, :effort, :notes])
)

Story.show_plan_summary!(story, plan)

today = App.project_today!(plan, actor: actor, date: ~D[2026-06-23])
Story.show_projection!(story, today)

App.log_track!(today,
  actor: actor,
  track: "reading",
  payload: %{amount: 25}
)

App.log_track!(today,
  actor: actor,
  track: "bodyweight",
  payload: %{amount: 82.5}
)

App.log_track!(today,
  actor: actor,
  track: "evening_reset",
  payload: %{checked_items: ["Tidy room", "Brush teeth"]}
)

App.log_track!(today,
  actor: actor,
  track: "weekly_pages",
  payload: %{amount: 100}
)

App.log_track!(today,
  actor: actor,
  track: "daily_steps",
  payload: %{amount: 1_000}
)

App.log_track!(today,
  actor: actor,
  track: "practice_item",
  payload: %{sets: 3, reps: 10, load: 40, effort: "steady", notes: "Felt smooth"}
)

completed = App.project_today!(plan, actor: actor, date: ~D[2026-06-23])
Story.show_projection!(story, completed)
Story.show_ai_today_context!(story, plan, on: ~D[2026-06-23])
