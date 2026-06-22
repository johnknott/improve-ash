defmodule Improve.Planning.ItemStateTest do
  use ExUnit.Case, async: true

  alias Improve.Planning.ItemState

  describe "calculate/3" do
    test "derives remaining quantity from starting facts and active effects" do
      result =
        ItemState.calculate(
          %{
            id: "vial-1",
            facts: %{
              "starting_quantity" => 5000,
              "unit" => "mcg",
              "low_quantity_threshold" => 500
            }
          },
          [
            %{
              id: "dose-1",
              effect_type: :subtract_quantity,
              quantity: 250,
              unit: "mcg",
              status: :active
            },
            %{
              id: "voided-dose",
              effect_type: :subtract_quantity,
              quantity: 100,
              unit: "mcg",
              status: :voided
            },
            %{id: "fill", effect_type: :add_quantity, quantity: 50, unit: "mcg", status: :active}
          ]
        )

      assert result.item_id == "vial-1"
      assert Decimal.equal?(result.calculated_state.current_quantity, Decimal.new(4800))
      assert result.calculated_state.unit == "mcg"
      assert Enum.map(result.active_effects, & &1.id) == ["dose-1", "fill"]
      assert result.warnings == []
    end

    test "voided effects no longer contribute when a replacement effect exists" do
      result =
        ItemState.calculate(
          %{
            starting_quantity: Decimal.new(5000),
            unit: "mcg"
          },
          [
            %{
              id: "original-effect",
              effect_type: :subtract_quantity,
              quantity: 250,
              unit: "mcg",
              status: :voided
            },
            %{
              id: "replacement-effect",
              effect_type: :subtract_quantity,
              quantity: 300,
              unit: "mcg",
              status: :active,
              replaces_item_effect_id: "original-effect"
            }
          ]
        )

      assert Decimal.equal?(result.calculated_state.current_quantity, Decimal.new(4700))
      assert Enum.map(result.active_effects, & &1.id) == ["replacement-effect"]
    end

    test "set quantity and correction effects replace the running quantity" do
      result =
        ItemState.calculate(
          %{starting_quantity: 100, unit: "units"},
          [
            %{effect_type: :subtract_quantity, quantity: 25, unit: "units"},
            %{effect_type: :set_quantity, quantity: 50, unit: "units"},
            %{effect_type: :add_quantity, quantity: 10, unit: "units"},
            %{effect_type: :correction, quantity: 42, unit: "units"}
          ]
        )

      assert Decimal.equal?(result.calculated_state.current_quantity, Decimal.new(42))
    end

    test "merges active set fact effects into calculated state" do
      result =
        ItemState.calculate(
          %{starting_quantity: 10, unit: "units", label: "before"},
          [
            %{effect_type: :set_fact, payload: %{"label" => "after", "storage" => "fridge"}},
            %{effect_type: :set_fact, payload: %{"ignored" => true}, status: :voided}
          ]
        )

      assert result.calculated_state.label == "after"
      assert result.calculated_state.storage == "fridge"
      refute Map.has_key?(result.calculated_state, :ignored)
    end

    test "returns plain-English warnings for low and insufficient future quantity" do
      result =
        ItemState.calculate(
          %{starting_quantity: 500, unit: "mcg", low_quantity_threshold: 300},
          [
            %{effect_type: :subtract_quantity, quantity: 250, unit: "mcg"}
          ],
          future_quantity_required: 300
        )

      assert Decimal.equal?(result.calculated_state.current_quantity, Decimal.new(250))

      assert Enum.map(result.warnings, & &1.code) == [
               :low_quantity,
               :insufficient_future_quantity
             ]

      assert Enum.all?(result.warnings, fn warning ->
               is_binary(warning.message) and warning.message != ""
             end)
    end

    test "ignores mismatched unit effects and records a warning" do
      result =
        ItemState.calculate(
          %{starting_quantity: 5000, unit: "mcg"},
          [
            %{effect_type: :subtract_quantity, quantity: 1, unit: "ml"}
          ]
        )

      assert Decimal.equal?(result.calculated_state.current_quantity, Decimal.new(5000))
      assert [%{code: :unit_mismatch}] = result.warnings
    end
  end
end
