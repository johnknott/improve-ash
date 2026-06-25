# Story: item state is derived from journal effects.
#
# This demonstrates a stateful item such as a supply bin. The item starts with a
# known quantity, events subtract from it, and current state is derived from the
# active effects rather than stored as a manually edited total.

alias Improve.App
alias Improve.Stories, as: Story

story =
  Story.begin!("stateful_item_effects", reset?: true)
  |> Story.user!("John", email: "story+stateful-item-effects@example.test")

actor = story.user

plan =
  App.create_plan!("Supply state plan",
    actor: actor,
    intention: "Track starting facts, item effects, and derived state",
    from: ~D[2026-06-22],
    until: ~D[2026-09-14]
  )

App.add_item_type!(plan, "Supply container",
  actor: actor,
  key: "supply_container",
  facts: [:starting_quantity, :unit, :low_quantity_threshold],
  display_hints: %{kind: "stateful_item"}
)

App.add_item!(plan, "Workshop bin",
  actor: actor,
  key: "workshop_bin",
  type: "supply_container",
  starting_quantity: 20,
  unit: "uses",
  low_at: 5
)

App.add_event_type!(plan, "Use recorded",
  actor: actor,
  key: "use_recorded",
  required_links: ["container"],
  payload: %{
    required: ["amount", "unit"],
    properties: %{
      amount: %{type: "number"},
      unit: %{type: "string"},
      note: %{type: "string"}
    }
  },
  effects: [
    App.subtract_quantity(
      item: "container",
      quantity: "payload.amount",
      unit: "payload.unit"
    )
  ]
)

Story.show_plan_summary!(story, plan)
Story.show_item_state!(story, plan, "workshop_bin")

App.log_event!(plan,
  actor: actor,
  event: "use_recorded",
  on: ~D[2026-06-22],
  summary: "Use recorded from Workshop bin",
  links: %{container: "workshop_bin"},
  payload: %{amount: 17, unit: "uses", note: "Large project day"}
)

Story.show_journal!(story, plan)
Story.show_item_state!(story, plan, "workshop_bin")
Story.show_ai_recent_journal!(story, plan, limit: 10)
Story.show_ai_item_state!(story, plan, "workshop_bin")
