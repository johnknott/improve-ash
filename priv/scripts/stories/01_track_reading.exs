# Story: a simple daily reading track.
#
# This is the smallest Improve loop in plain English: create a plan, add one
# daily track, project today's work, log that it happened, then show the journal
# and AI-readable context. It proves the backend can support the basic
# "plan -> today -> log -> review the record" flow without any special-case UI.

alias Improve.App
alias Improve.Stories, as: Story
import Improve.App, only: [fixed: 2, number: 1]

story =
  Story.begin!("track_reading", reset?: true)
  |> Story.user!("John", email: "story+track-reading@example.test")

actor = story.user

plan =
  App.create_plan!("Read more consistently",
    actor: actor,
    intention: "Read a little every day",
    from: ~D[2026-06-23],
    until: ~D[2026-07-23]
  )

App.add_track!(plan, "Read 20 pages",
  actor: actor,
  key: "daily_reading",
  schedule: App.every_day(),
  target: fixed(20, "pages"),
  records: number("pages")
)

Story.show_plan_summary!(story, plan)

today = App.project_today!(plan, actor: actor, date: ~D[2026-06-23])
Story.show_projection!(story, today)

App.log_track!(today,
  actor: actor,
  track: "daily_reading",
  payload: %{amount: 25, note: "Read before bed"}
)

Story.show_journal!(story, plan)
Story.show_ai_plan_summary!(story, plan)
Story.show_ai_today_context!(story, plan, on: ~D[2026-06-23])
Story.show_ai_recent_journal!(story, plan, limit: 10)
