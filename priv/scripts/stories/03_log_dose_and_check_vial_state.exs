alias Improve.Stories, as: Story

story =
  Story.begin!("vial_inventory_basic", reset?: true)
  |> Story.user!("John", email: "story+vial-inventory-basic@example.test")

plan =
  Story.create_plan!(story, "Vial inventory plan",
    intention: "Track vial quantity and dose history",
    from: ~D[2026-06-22],
    until: ~D[2026-09-14]
  )

Story.add_item_type!(story, plan, "Peptide vial",
  key: "peptide_vial",
  display_hints: %{kind: "inventory"}
)

Story.add_item!(story, plan, "Retatrutide vial 1",
  key: "reta_vial_1",
  type: "peptide_vial",
  stateful: true,
  facts: %{
    starting_quantity: 5000,
    unit: "mcg",
    low_quantity_threshold: 500
  }
)

Story.add_event_type!(story, plan, "Dose taken",
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
    Story.subtract_quantity(
      from: "source_vial",
      quantity: "payload.amount",
      unit: "payload.unit"
    )
  ]
)

Story.show_plan_summary!(story, plan)
Story.show_item_state!(story, plan, "reta_vial_1")

Story.log_event!(story, plan,
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
