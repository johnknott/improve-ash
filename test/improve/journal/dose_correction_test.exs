defmodule Improve.Journal.DoseCorrectionTest do
  use Improve.DataCase, async: true

  alias Improve.Accounts
  alias Improve.Fixtures.VialPlan
  alias Improve.Journal
  alias Improve.Plans

  describe "correct_dose_event!/2" do
    test "voids the original effect and replaces the dose without deleting history" do
      user =
        Accounts.create_user!(%{
          email: "dose-correction@example.com",
          full_name: "Dose Correction"
        })

      %{plan: plan} = VialPlan.install!(user, starts_on: ~D[2026-06-22])

      items =
        Plans.list_items!(actor: user, query: [filter: [plan_id: plan.id]])
        |> Map.new(&{&1.key, &1})

      event_types =
        Plans.list_event_types!(actor: user, query: [filter: [plan_id: plan.id]])
        |> Map.new(&{&1.key, &1})

      original =
        Journal.log_dose_event!(
          %{
            plan: plan,
            event_type: event_types["take_dose"],
            source_vial: items["retatrutide_vial_1"],
            amount: 250,
            unit: "mcg",
            route: "subcutaneous",
            site: "abdomen",
            effective_at: ~U[2026-06-22 08:00:00Z],
            recorded_at: ~U[2026-06-22 08:01:00Z],
            summary: "Dose recorded from Retatrutide vial 1"
          },
          actor: user
        )

      assert [original_effect] = original.item_effects

      correction =
        Journal.correct_dose_event!(
          %{
            plan: plan,
            event_type: event_types["take_dose"],
            source_vial: items["retatrutide_vial_1"],
            original_event: original.event,
            original_effect: original_effect,
            amount: 300,
            unit: "mcg",
            route: "subcutaneous",
            site: "abdomen",
            effective_at: ~U[2026-06-22 08:00:00Z],
            recorded_at: ~U[2026-06-22 08:05:00Z],
            corrected_at: ~U[2026-06-22 08:05:00Z],
            summary: "Corrected dose from Retatrutide vial 1",
            correction_note: "Dose corrected from 250 mcg to 300 mcg"
          },
          actor: user
        )

      assert correction.corrected_event.id == original.event.id
      assert correction.corrected_event.status == :corrected

      assert DateTime.compare(correction.corrected_event.voided_at, ~U[2026-06-22 08:05:00Z]) ==
               :eq

      assert correction.corrected_event.note == "Dose corrected from 250 mcg to 300 mcg"

      assert correction.voided_effect.id == original_effect.id
      assert correction.voided_effect.status == :voided

      assert DateTime.compare(correction.voided_effect.voided_at, ~U[2026-06-22 08:05:00Z]) ==
               :eq

      assert correction.replacement_event.status == :active
      assert correction.replacement_event.quantity == Decimal.new(300)
      assert correction.replacement_event.unit == "mcg"
      assert correction.replacement_event.replaces_event_instance_id == original.event.id

      assert correction.replacement_link.role == "source_vial"
      assert correction.replacement_link.item_id == items["retatrutide_vial_1"].id

      assert [replacement_effect] = correction.replacement_effects
      assert replacement_effect.status == :active
      assert replacement_effect.quantity == Decimal.new(300)
      assert replacement_effect.unit == "mcg"
      assert replacement_effect.replaces_item_effect_id == original_effect.id

      state = Journal.get_item_state!(items["retatrutide_vial_1"], actor: user)

      assert Decimal.equal?(state.calculated_state.current_quantity, Decimal.new(4700))
      assert Enum.map(state.active_effects, & &1.id) == [replacement_effect.id]
      assert state.warnings == []

      journal = Journal.read_journal!(plan, actor: user)

      assert Enum.map(journal, & &1.id) == [original.event.id, correction.replacement_event.id]
      assert Enum.map(journal, & &1.status) == [:corrected, :active]
      assert Enum.map(journal, & &1.replaces_event_instance_id) == [nil, original.event.id]
    end
  end
end
