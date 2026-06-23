alias Improve.Stories, as: Story

story =
  Story.begin!("correct_logged_event", reset?: true)
  |> Story.user!("John", email: "story+correct-logged-event@example.test")

plan =
  Story.create_plan!(story, "Vial correction plan",
    intention: "Track vial quantity and correct mistakes without losing history",
    from: ~D[2026-06-22],
    until: ~D[2026-09-14]
  )

Story.add_item_type!(story, plan, "Peptide vial", key: "peptide_vial")

Story.add_item!(story, plan, "Retatrutide vial 1",
  key: "reta_vial_1",
  type: "peptide_vial",
  stateful: true,
  facts: %{starting_quantity: 5000, unit: "mcg"}
)

Story.add_event_type!(story, plan, "Dose taken",
  key: "dose_taken",
  required_links: ["source_vial"],
  payload: %{required: ["amount", "unit"]},
  effects: [
    Story.subtract_quantity(from: "source_vial", quantity: "payload.amount", unit: "payload.unit")
  ]
)

Story.show_item_state!(story, plan, "reta_vial_1")

original =
  Story.log_event!(story, plan,
    event: "dose_taken",
    on: ~D[2026-06-22],
    summary: "Dose taken from Retatrutide vial 1",
    links: %{source_vial: "reta_vial_1"},
    payload: %{amount: 250, unit: "mcg", site: "abdomen"}
  )

Story.show_journal!(story, plan)
Story.show_item_state!(story, plan, "reta_vial_1")

Story.correct_event!(story, original,
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
