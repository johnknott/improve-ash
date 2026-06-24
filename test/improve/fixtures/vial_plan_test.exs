defmodule Improve.Fixtures.VialPlanTest do
  use Improve.DataCase, async: true

  alias Improve.Accounts
  alias Improve.Fixtures.VialPlan
  alias Improve.Planning.Diagnostics
  alias Improve.Plans

  describe "install!/2" do
    test "installs the persisted vial demo plan with valid effect rules" do
      user =
        Accounts.create_user!(%{
          email: "vial-demo@example.com",
          full_name: "Vial Demo"
        })

      result = VialPlan.install!(user, starts_on: ~D[2026-06-22])
      plan = result.plan

      assert plan.name == "Retatrutide Inventory"
      assert plan.intention == "Track vial quantity and dose history"
      assert plan.starts_on == ~D[2026-06-22]
      assert plan.ends_on == ~D[2026-09-14]
      assert plan.status == :active
      assert plan.source_kind == :demo
      assert plan.source_key == "vial_inventory"

      assert Plans.summarize_plan!(plan, actor: user) == %{
               item_types: 2,
               items: 2,
               pools: 0,
               pool_memberships: 0,
               environments: 0,
               event_types: 1,
               session_templates: 0,
               session_slots: 0,
               tracks: 0,
               schedules: 0
             }

      item_types = list!(Plans.list_item_types(actor: user, query: [filter: [plan_id: plan.id]]))
      items = list!(Plans.list_items(actor: user, query: [filter: [plan_id: plan.id]]))

      event_types =
        list!(Plans.list_event_types(actor: user, query: [filter: [plan_id: plan.id]]))

      assert keys(item_types) == ["injection_site", "peptide_vial"]
      assert names(items) == ["Abdomen", "Retatrutide vial 1"]

      vial = Enum.find(items, &(&1.key == "retatrutide_vial_1"))
      assert vial.stateful == true
      assert vial.facts["compound"] == "Retatrutide"
      assert vial.facts["starting_quantity"] == 5000
      assert vial.facts["unit"] == "mcg"
      assert vial.facts["low_quantity_threshold"] == 500

      assert [%{key: "take_dose", name: "Take Dose"} = take_dose] = event_types

      roles = take_dose.item_link_roles["roles"]
      assert Enum.any?(roles, &(&1["role"] == "source_vial" and &1["required"] == true))
      assert Enum.any?(roles, &(&1["role"] == "site" and &1["required"] == false))

      assert [
               %{
                 "role" => "source_vial",
                 "effect_type" => "subtract_quantity",
                 "quantity_path" => "payload.amount",
                 "unit_path" => "payload.unit"
               }
             ] = take_dose.effect_rules["rules"]

      assert Diagnostics.validate_event_type(take_dose) == []
    end

    test "diagnostics explain effect rules that reference undeclared roles" do
      event_type = %{
        item_link_roles: %{"roles" => [%{"role" => "source_vial"}]},
        effect_rules: %{
          "rules" => [%{"role" => "missing_role", "effect_type" => "subtract_quantity"}]
        }
      }

      assert [
               %{
                 code: :effect_rule_unknown_role,
                 message: "Effect rule refers to an item link role that is not declared.",
                 details: %{role: "missing_role"}
               }
             ] = Diagnostics.validate_event_type(event_type)
    end
  end

  defp list!({:ok, records}), do: records

  defp keys(records) do
    records
    |> Enum.map(& &1.key)
    |> Enum.sort()
  end

  defp names(records) do
    records
    |> Enum.map(& &1.name)
    |> Enum.sort()
  end
end
