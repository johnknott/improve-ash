defmodule Improve.Planning.EffectRuleInterpreterTest do
  use ExUnit.Case, async: true

  alias Improve.Planning.EffectRuleInterpreter

  describe "interpret/1" do
    test "returns effect specs for linked items and payload paths" do
      result =
        EffectRuleInterpreter.interpret(%{
          rules: [
            %{
              "role" => "source_vial",
              "effect_type" => "subtract_quantity",
              "quantity_path" => "payload.amount",
              "unit_path" => "payload.unit"
            }
          ],
          item_links: [
            %{role: "source_vial", item_id: "vial-1"}
          ],
          payload: %{"amount" => 250, "unit" => "mcg"}
        })

      assert result.diagnostics == []

      assert result.effects == [
               %{
                 item_id: "vial-1",
                 effect_type: :subtract_quantity,
                 quantity: 250,
                 unit: "mcg",
                 payload: %{
                   "rule" => %{
                     "role" => "source_vial",
                     "effect_type" => "subtract_quantity",
                     "quantity_path" => "payload.amount",
                     "unit_path" => "payload.unit"
                   }
                 }
               }
             ]
    end

    test "supports multiple item links for the same role" do
      result =
        EffectRuleInterpreter.interpret(%{
          rules: [
            %{
              "role" => "supply",
              "effect_type" => "add_quantity",
              "quantity_path" => "payload.count",
              "unit_path" => "payload.unit"
            }
          ],
          item_links: [
            %{role: "supply", item_id: "box-1"},
            %{role: "supply", item_id: "box-2"}
          ],
          payload: %{"count" => 1, "unit" => "box"}
        })

      assert Enum.map(result.effects, & &1.item_id) == ["box-1", "box-2"]
      assert Enum.map(result.effects, & &1.effect_type) == [:add_quantity, :add_quantity]
      assert result.diagnostics == []
    end

    test "reads nested payload paths the same way diagnostics do" do
      result =
        EffectRuleInterpreter.interpret(%{
          rules: [
            %{
              "role" => "source_vial",
              "effect_type" => "subtract_quantity",
              "quantity_path" => "payload.dose.amount",
              "unit_path" => "payload.dose.unit"
            }
          ],
          item_links: [
            %{role: "source_vial", item_id: "vial-1"}
          ],
          payload: %{"dose" => %{"amount" => 250, "unit" => "mcg"}}
        })

      assert result.diagnostics == []
      assert [%{quantity: 250, unit: "mcg"}] = result.effects
    end

    test "returns diagnostics for missing item links" do
      result =
        EffectRuleInterpreter.interpret(%{
          rules: [
            %{
              "role" => "source_vial",
              "effect_type" => "subtract_quantity",
              "quantity_path" => "payload.amount",
              "unit_path" => "payload.unit"
            }
          ],
          item_links: [],
          payload: %{"amount" => 250, "unit" => "mcg"}
        })

      assert result.effects == []
      assert result.diagnostics == ["No item link found for effect role source_vial."]
    end

    test "returns diagnostics for unsupported effect types and missing payload paths" do
      result =
        EffectRuleInterpreter.interpret(%{
          rules: [
            %{
              "role" => "source_vial",
              "effect_type" => "multiply_quantity",
              "quantity_path" => "payload.amount",
              "unit_path" => "payload.unit"
            },
            %{
              "role" => "source_vial",
              "effect_type" => "subtract_quantity",
              "quantity_path" => "payload.missing_amount",
              "unit_path" => "payload.unit"
            },
            %{
              "role" => "source_vial",
              "effect_type" => "subtract_quantity",
              "quantity_path" => "payload.amount",
              "unit_path" => "payload.missing_unit"
            }
          ],
          item_links: [
            %{role: "source_vial", item_id: "vial-1"}
          ],
          payload: %{"amount" => 250, "unit" => "mcg"}
        })

      assert result.effects == []

      assert result.diagnostics == [
               "Effect rule for role source_vial uses unsupported effect type multiply_quantity.",
               "Effect rule for role source_vial could not read quantity at payload.missing_amount.",
               "Effect rule for role source_vial could not read unit at payload.missing_unit."
             ]
    end
  end
end
