defmodule Improve.Journal.DoseLoggingTest do
  use Improve.DataCase, async: true

  alias Improve.Accounts
  alias Improve.Fixtures.VialPlan
  alias Improve.Journal
  alias Improve.Plans

  describe "log_linked_item_event!/2" do
    test "creates an event, source vial link, item effect, and derived vial state" do
      user =
        Accounts.create_user!(%{
          email: "dose-log@example.com",
          full_name: "Dose Log"
        })

      %{plan: plan} = VialPlan.install!(user, starts_on: ~D[2026-06-22])

      items =
        Plans.list_items!(actor: user, query: [filter: [plan_id: plan.id]])
        |> Map.new(&{&1.key, &1})

      event_types =
        Plans.list_event_types!(actor: user, query: [filter: [plan_id: plan.id]])
        |> Map.new(&{&1.key, &1})

      log =
        Journal.log_linked_item_event!(
          %{
            plan: plan,
            event_type: event_types["take_dose"],
            linked_item: items["retatrutide_vial_1"],
            role: "source_vial",
            quantity: 250,
            unit: "mcg",
            payload: %{"route" => "subcutaneous", "site" => "abdomen"},
            effective_at: ~U[2026-06-22 08:00:00Z],
            recorded_at: ~U[2026-06-22 08:01:00Z],
            summary: "Dose recorded from Retatrutide vial 1"
          },
          actor: user
        )

      assert log.event.status == :active
      assert log.event.quantity == Decimal.new(250)
      assert log.event.unit == "mcg"
      assert log.event.payload["amount"] == 250
      assert log.event.payload["unit"] == "mcg"

      assert log.event_item_link.role == "source_vial"
      assert log.event_item_link.item_id == items["retatrutide_vial_1"].id

      assert [effect] = log.item_effects
      assert effect.status == :active
      assert effect.effect_type == :subtract_quantity
      assert effect.quantity == Decimal.new(250)
      assert effect.unit == "mcg"
      assert effect.event_instance_id == log.event.id

      state = Journal.get_item_state!(items["retatrutide_vial_1"], actor: user)

      assert state.starting_facts["starting_quantity"] == 5000
      assert Decimal.equal?(state.calculated_state.current_quantity, Decimal.new(4750))
      assert state.calculated_state.unit == "mcg"
      assert Enum.map(state.active_effects, & &1.id) == [effect.id]
      assert state.warnings == []
    end
  end
end
