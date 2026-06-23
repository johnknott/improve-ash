alias Improve.App
alias Improve.Stories, as: Story

story =
  Story.begin!("correct_logged_event", reset?: true)
  |> Story.user!("John", email: "story+correct-logged-event@example.test")

actor = story.user

plan =
  App.create_plan!("Vial correction plan",
    actor: actor,
    intention: "Track vial quantity and correct mistakes without losing history",
    from: ~D[2026-06-22],
    until: ~D[2026-09-14]
  )

App.add_item_type!(plan, "Peptide vial", actor: actor, key: "peptide_vial")

App.add_item!(plan, "Retatrutide vial 1",
  actor: actor,
  key: "reta_vial_1",
  type: "peptide_vial",
  stateful: true,
  facts: %{starting_quantity: 5000, unit: "mcg"}
)

App.add_event_type!(plan, "Dose taken",
  actor: actor,
  key: "dose_taken",
  required_links: ["source_vial"],
  payload: %{required: ["amount", "unit"]},
  effects: [
    App.subtract_quantity(from: "source_vial", quantity: "payload.amount", unit: "payload.unit")
  ]
)

Story.show_item_state!(story, plan, "reta_vial_1")

original =
  App.log_event!(plan,
    actor: actor,
    event: "dose_taken",
    on: ~D[2026-06-22],
    summary: "Dose taken from Retatrutide vial 1",
    links: %{source_vial: "reta_vial_1"},
    payload: %{amount: 250, unit: "mcg", site: "abdomen"}
  )

Story.show_journal!(story, plan)
Story.show_item_state!(story, plan, "reta_vial_1")

App.correct_event!(original,
  actor: actor,
  corrected_at: ~U[2026-06-22 21:00:00Z],
  reason: "Amount was entered incorrectly",
  replacement: [
    event: "dose_taken",
    effective_at: ~U[2026-06-22 20:00:00Z],
    summary: "Corrected dose from Retatrutide vial 1",
    links: %{source_vial: "reta_vial_1"},
    payload: %{amount: 200, unit: "mcg", site: "abdomen"}
  ]
)

Story.show_journal!(story, plan)
Story.show_item_state!(story, plan, "reta_vial_1")
Story.show_ai_item_state!(story, plan, "reta_vial_1")
