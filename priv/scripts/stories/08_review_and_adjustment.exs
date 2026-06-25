alias Improve.App
alias Improve.Stories, as: Story
alias Improve.Stories.Print

story =
  Story.begin!("review_and_adjustment", reset?: true)
  |> Story.user!("John", email: "story+review-and-adjustment@example.test")

actor = story.user

plan =
  App.create_plan!("Weekly review plan",
    actor: actor,
    intention: "Review recent history before adjusting the plan",
    from: ~D[2026-06-22],
    until: ~D[2026-07-23]
  )

App.add_event_type!(plan, "Pages read",
  actor: actor,
  key: "pages_read",
  payload: %{required: ["amount"]}
)

App.add_track!(plan, "Read 20 pages",
  actor: actor,
  key: "daily_reading",
  event: "pages_read",
  schedule: App.every_day(),
  target: App.fixed(20, "pages"),
  records: App.number("pages")
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

App.add_session!(plan, "Focused practice",
  actor: actor,
  key: "focused_practice",
  schedule: App.every_week(times: 2, on: [:monday, :thursday]),
  slots: [
    App.choose(2,
      from: "technique",
      suggest: App.adaptive(fields: [:rounds, :duration_minutes], effort: :effort, review: :weekly),
      start_with: %{rounds: 2, duration_minutes: 10, effort: "easy"}
    )
  ]
)

monday = App.project_today!(plan, actor: actor, date: ~D[2026-06-22])
started = App.start_session!(monday, "focused_practice", actor: actor)

App.log_session_slot!(started,
  actor: actor,
  slot: "technique",
  item: "piano_scales",
  event: "practice_logged",
  payload: %{rounds: 2, duration_minutes: 12, effort: "steady"},
  note: "Good starting point"
)

App.log_track!(monday,
  actor: actor,
  track: "daily_reading",
  payload: %{amount: 25, note: "Read before bed"}
)

review_day = App.project_today!(plan, actor: actor, date: ~D[2026-06-25])

Story.show_projection!(story, review_day)
Story.show_review!(story, plan, on: ~D[2026-06-25])

applied =
  App.apply_proposal!(
    plan,
    %{
      kind: :extend_plan,
      requires_approval: true,
      effect: :committed,
      proposed_edit: %{action: :extend_plan, weeks: 1}
    },
    actor: actor
  )

Print.section("Applied Proposal")

Print.key_values([
  {"Action", applied.action},
  {"Plan ends on", applied.plan.ends_on}
])

extended_day = App.project_today!(applied.plan, actor: actor, date: applied.plan.ends_on)
Story.show_projection!(story, extended_day)

Story.show_ai_today_context!(story, plan, on: ~D[2026-06-25])
Story.show_ai_recent_journal!(story, plan, limit: 10)
