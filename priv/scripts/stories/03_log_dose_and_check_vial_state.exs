alias Improve.App
alias Improve.Stories, as: Story

story =
  Story.begin!("vial_inventory_basic", reset?: true)
  |> Story.user!("John", email: "story+vial-inventory-basic@example.test")

actor = story.user

plan =
  App.create_plan!("Vial inventory plan",
    actor: actor,
    intention: "Track vial quantity and dose history",
    from: ~D[2026-06-22],
    until: ~D[2026-09-14]
  )

App.add_item_type!(plan, "Peptide vial",
  actor: actor,
  key: "peptide_vial",
  display_hints: %{kind: "inventory"}
)

App.add_item!(plan, "Retatrutide vial 1",
  actor: actor,
  key: "reta_vial_1",
  type: "peptide_vial",
  stateful: true,
  facts: %{
    starting_quantity: 5000,
    unit: "mcg",
    low_quantity_threshold: 500
  }
)

App.add_event_type!(plan, "Dose taken",
  actor: actor,
  key: "dose_taken",
  required_links: ["source_vial"],
  payload: %{
    required: ["amount", "unit"],
    properties: %{
      amount: %{type: "number"},
      unit: %{type: "string"},
      site: %{type: "string"},
      note: %{type: "string"}
    }
  },
  effects: [
    App.subtract_quantity(
      from: "source_vial",
      quantity: "payload.amount",
      unit: "payload.unit"
    )
  ]
)

Story.show_plan_summary!(story, plan)
Story.show_item_state!(story, plan, "reta_vial_1")

App.log_event!(plan,
  actor: actor,
  event: "dose_taken",
  on: ~D[2026-06-22],
  summary: "Dose taken from Retatrutide vial 1",
  links: %{source_vial: "reta_vial_1"},
  payload: %{amount: 250, unit: "mcg", site: "abdomen", note: "Morning dose"}
)

Story.show_journal!(story, plan)
Story.show_item_state!(story, plan, "reta_vial_1")
Story.show_ai_recent_journal!(story, plan, limit: 10)
Story.show_ai_item_state!(story, plan, "reta_vial_1")
