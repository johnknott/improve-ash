defmodule Improve.Planning.PlanDraftExporterTest do
  use Improve.DataCase, async: true

  alias Improve.Accounts
  alias Improve.Fixtures.GymPlan
  alias Improve.Fixtures.VialPlan
  alias Improve.Planning.Diagnostics
  alias Improve.Planning.PlanDraft
  alias Improve.Plans

  @uuid_pattern ~r/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/

  describe "export_plan_draft/2" do
    test "exports the gym demo plan with stable-key references and deterministic output" do
      user =
        Accounts.create_user!(%{
          email: "export-gym@example.com",
          full_name: "Export Gym"
        })

      %{plan: plan} = GymPlan.install!(user, starts_on: ~D[2026-06-22])

      assert {:ok, draft} = Plans.export_plan_draft(plan, actor: user)
      assert draft == Plans.export_plan_draft!(plan.id, actor: user)

      assert draft.schema == "improve.plan_draft"
      assert draft.version == PlanDraft.current_version()
      assert draft.key == "gym"
      assert draft.name == "General Fitness"
      assert draft.starts_on == "2026-06-22"
      assert draft.ends_on == "2026-08-17"
      assert draft.source == %{"kind" => "demo", "key" => "gym"}

      assert Enum.map(draft.item_types, & &1.key) == [
               "cardio_machine",
               "exercise",
               "gym_environment"
             ]

      assert Enum.find(draft.items, &(&1.key == "chest_press")).item_type_key == "exercise"

      assert Enum.find(draft.pools, &(&1.key == "push")).item_keys == [
               "cable_fly",
               "chest_press",
               "shoulder_press"
             ]

      assert Enum.find(draft.environments, &(&1.key == "jd_gym")).available_item_keys == [
               "bike",
               "cable_fly",
               "chest_press",
               "lat_pulldown",
               "rower",
               "seated_row",
               "shoulder_press"
             ]

      assert [
               %{
                 key: "upper_biased_gym_visit",
                 environment_key: "jd_gym",
                 slots: slots
               }
             ] = draft.session_templates

      assert Enum.map(slots, &{&1.key, &1.pool_key, &1.count}) == [
               {"push", "push", 2},
               {"pull", "pull", 2},
               {"cardio", "cardio", 1}
             ]

      assert [
               %{
                 owner_type: "session_template",
                 owner_key: "upper_biased_gym_visit",
                 kind: "times_per_week",
                 rules: %{
                   "times" => 3,
                   "minimum_gap_days" => 1
                 }
               }
             ] = draft.schedules

      assert Diagnostics.validate_plan_draft(draft) == []
      refute Jason.encode!(draft) =~ @uuid_pattern
    end

    test "exports the vial demo plan without internal IDs" do
      user =
        Accounts.create_user!(%{
          email: "export-vial@example.com",
          full_name: "Export Vial"
        })

      %{plan: plan} = VialPlan.install!(user, starts_on: ~D[2026-06-22])

      assert {:ok, draft} = Plans.export_plan_draft(plan, actor: user)

      assert draft.key == "vial_inventory"
      assert draft.name == "Retatrutide Inventory"
      assert Enum.map(draft.item_types, & &1.key) == ["injection_site", "peptide_vial"]

      assert Enum.find(draft.items, &(&1.key == "retatrutide_vial_1")).item_type_key ==
               "peptide_vial"

      assert [
               %{
                 key: "take_dose",
                 item_link_roles: %{
                   "roles" => roles
                 },
                 effect_rules: %{
                   "rules" => [
                     %{
                       "role" => "source_vial",
                       "effect_type" => "subtract_quantity",
                       "quantity_path" => "payload.amount",
                       "unit_path" => "payload.unit"
                     }
                   ]
                 }
               }
             ] = draft.event_types

      assert Enum.any?(
               roles,
               &(&1["role"] == "source_vial" and &1["item_type_key"] == "peptide_vial")
             )

      assert draft.pools == []
      assert draft.environments == []
      assert draft.session_templates == []
      assert draft.schedules == []

      assert Diagnostics.validate_plan_draft(draft) == []
      refute Jason.encode!(draft) =~ @uuid_pattern
    end
  end
end
