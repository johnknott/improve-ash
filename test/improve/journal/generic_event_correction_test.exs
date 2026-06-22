defmodule Improve.Journal.GenericEventCorrectionTest do
  use Improve.DataCase, async: true

  alias Improve.Accounts
  alias Improve.Journal
  alias Improve.Plans

  describe "correct_generic_event!/2" do
    test "corrects a non-vial event and replaces its generated effect" do
      user =
        Accounts.create_user!(%{
          email: "generic-correction@example.com",
          full_name: "Generic Correction"
        })

      plan = plan!(user)
      item_type = item_type!(user, plan)
      book = book!(user, plan, item_type)
      event_type = reading_event_type!(user, plan, item_type)

      original =
        Journal.log_generic_event!(
          %{
            plan_id: plan.id,
            event_type_id: event_type.id,
            effective_at: ~U[2026-06-22 20:00:00Z],
            recorded_at: ~U[2026-06-22 20:01:00Z],
            summary: "Read 20 pages",
            quantity: 20,
            unit: "pages",
            payload: %{"amount" => 20, "unit" => "pages"},
            item_links: [%{role: "book", item_id: book.id}]
          },
          actor: user
        )

      assert [original_effect] = original.item_effects

      correction =
        Journal.correct_generic_event!(
          %{
            original_event: original.event,
            original_effects: [original_effect],
            corrected_at: ~U[2026-06-22 20:05:00Z],
            correction_note: "Corrected pages read from 20 to 35",
            replacement: %{
              plan_id: plan.id,
              event_type_id: event_type.id,
              effective_at: ~U[2026-06-22 20:00:00Z],
              recorded_at: ~U[2026-06-22 20:05:00Z],
              summary: "Read 35 pages",
              quantity: 35,
              unit: "pages",
              payload: %{"amount" => 35, "unit" => "pages"},
              item_links: [%{role: "book", item_id: book.id}]
            }
          },
          actor: user
        )

      assert correction.corrected_event.id == original.event.id
      assert correction.corrected_event.status == :corrected
      assert correction.corrected_event.note == "Corrected pages read from 20 to 35"

      assert [voided_effect] = correction.voided_effects
      assert voided_effect.id == original_effect.id
      assert voided_effect.status == :voided

      assert correction.replacement.event.replaces_event_instance_id == original.event.id
      assert [replacement_link] = correction.replacement.event_item_links
      assert replacement_link.role == "book"
      assert replacement_link.item_id == book.id
      assert replacement_link.metadata["corrects_event_instance_id"] == original.event.id

      assert [replacement_effect] = correction.replacement.item_effects
      assert replacement_effect.effect_type == :add_quantity
      assert replacement_effect.quantity == Decimal.new(35)
      assert replacement_effect.unit == "pages"
      assert replacement_effect.replaces_item_effect_id == original_effect.id

      state = Journal.get_item_state!(book, actor: user)

      assert Decimal.equal?(state.calculated_state.current_quantity, Decimal.new(35))
      assert Enum.map(state.active_effects, & &1.id) == [replacement_effect.id]

      journal = Journal.read_journal!(plan, actor: user)

      assert Enum.map(journal, & &1.id) == [original.event.id, correction.replacement.event.id]
      assert Enum.map(journal, & &1.status) == [:corrected, :active]
    end

    test "returns diagnostics before starting persistence" do
      user =
        Accounts.create_user!(%{
          email: "generic-correction-error@example.com",
          full_name: "Generic Correction Error"
        })

      assert {:error, diagnostics} = Journal.correct_generic_event(%{}, actor: user)

      assert diagnostics == [
               "Original event is required.",
               "Corrected time is required.",
               "Replacement event is required.",
               "Event log command must be a map."
             ]
    end
  end

  defp plan!(user) do
    Plans.create_plan!(
      %{
        name: "Reading",
        intention: "Track reading progress",
        starts_on: ~D[2026-06-22],
        ends_on: ~D[2026-07-20]
      },
      actor: user
    )
  end

  defp item_type!(user, plan) do
    Plans.create_item_type!(
      %{
        plan_id: plan.id,
        key: "book",
        name: "Book"
      },
      actor: user
    )
  end

  defp book!(user, plan, item_type) do
    Plans.create_item!(
      %{
        plan_id: plan.id,
        item_type_id: item_type.id,
        key: "deep_work",
        name: "Deep Work",
        stateful: true,
        facts: %{"starting_quantity" => 0, "unit" => "pages"}
      },
      actor: user
    )
  end

  defp reading_event_type!(user, plan, item_type) do
    Plans.create_event_type!(
      %{
        plan_id: plan.id,
        key: "read_pages",
        name: "Read Pages",
        item_link_roles: %{
          "roles" => [
            %{
              "role" => "book",
              "item_type_key" => item_type.key,
              "required" => true
            }
          ]
        },
        effect_rules: %{
          "rules" => [
            %{
              "role" => "book",
              "effect_type" => "add_quantity",
              "quantity_path" => "payload.amount",
              "unit_path" => "payload.unit"
            }
          ]
        }
      },
      actor: user
    )
  end
end
