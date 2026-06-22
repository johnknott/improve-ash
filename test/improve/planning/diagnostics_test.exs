defmodule Improve.Planning.DiagnosticsTest do
  use ExUnit.Case, async: true

  alias Improve.Planning.Diagnostics

  describe "validate_plan_draft/1" do
    test "returns plain-English diagnostics for malformed authored content" do
      draft = %{
        item_types: [
          %{key: "exercise", name: "Exercise"}
        ],
        pools: [
          %{key: "push", name: "Push exercises"},
          %{key: "push", name: "Duplicate push exercises"}
        ],
        session_templates: [
          %{
            key: "upper",
            slots: [
              %{key: "cardio", pool_key: "cardio"}
            ]
          }
        ],
        event_types: [
          %{
            key: "take_dose",
            item_link_roles: %{
              roles: [
                %{role: "source_vial", item_type_key: "peptide_vial", required: true}
              ]
            },
            effect_rules: %{
              rules: [
                %{
                  role: "source_vial",
                  effect_type: "subtract_quantity",
                  quantity_path: "payload.amount",
                  unit_path: "payload.unit"
                },
                %{
                  role: "missing_role",
                  effect_type: "subtract_quantity",
                  quantity_path: "payload.amount",
                  unit_path: "payload.unit"
                }
              ]
            }
          }
        ],
        schedules: [
          %{key: "strange", kind: "moon_phase"},
          %{key: "completion", kind: "after_completion"}
        ],
        sample_events: [
          %{
            key: "bad_dose",
            event_type_key: "take_dose",
            item_links: %{},
            payload: %{amount: "a little", unit: "mcg"}
          }
        ]
      }

      diagnostics = Diagnostics.validate_plan_draft(draft)

      assert diagnostic(diagnostics, :duplicate_key).message ==
               "This plan defines the same key more than once in pools."

      assert diagnostic(diagnostics, :duplicate_key).path == ["pools", "push"]
      assert diagnostic(diagnostics, :duplicate_key).ref == "push"

      assert diagnostic(diagnostics, :missing_pool).message ==
               "This session slot points at a pool that does not exist."

      assert diagnostic(diagnostics, :missing_pool).path == [
               "session_templates",
               "upper",
               "slots",
               "cardio",
               "pool_key"
             ]

      assert diagnostic(diagnostics, :missing_pool).ref == "cardio"

      assert diagnostic(diagnostics, :missing_item_type).message ==
               "This event item role points at an item type that does not exist."

      assert diagnostic(diagnostics, :missing_item_type).ref == "peptide_vial"

      assert diagnostic(diagnostics, :effect_rule_unknown_role).message ==
               "Effect rule refers to an item link role that is not declared."

      assert diagnostic(diagnostics, :effect_rule_unknown_role).ref == "missing_role"

      assert diagnostic(diagnostics, :invalid_schedule_kind).message ==
               "This schedule uses a kind that Improve does not recognize."

      assert diagnostic(diagnostics, :invalid_schedule_kind).ref == "moon_phase"

      assert diagnostic(diagnostics, :unsupported_schedule_rule).message ==
               "This schedule kind is recognized, but the POC planner does not support it yet."

      assert diagnostic(diagnostics, :unsupported_schedule_rule).ref == "after_completion"

      assert diagnostic(diagnostics, :missing_required_item_link_role).message ==
               "This dose event is missing the required source vial link."

      assert diagnostic(diagnostics, :missing_required_item_link_role).path == [
               "events",
               "bad_dose",
               "item_links",
               "source_vial"
             ]

      assert diagnostic(diagnostics, :effect_rule_quantity_incompatible).message ==
               "This dose event quantity cannot be used by its item effect rule."

      assert diagnostic(diagnostics, :effect_rule_quantity_incompatible).path == [
               "events",
               "bad_dose",
               "payload",
               "amount"
             ]

      assert Enum.all?(diagnostics, &(&1.severity == :error))
    end

    test "returns an empty list for a supported minimal draft" do
      draft = %{
        item_types: [%{key: "exercise", name: "Exercise"}],
        pools: [%{key: "push", name: "Push"}],
        session_templates: [
          %{key: "upper", slots: [%{key: "press", pool_key: "push"}]}
        ],
        event_types: [
          %{
            key: "workout_set",
            item_link_roles: %{
              roles: [%{role: "exercise", item_type_key: "exercise", required: true}]
            },
            effect_rules: %{rules: []}
          }
        ],
        schedules: [%{key: "upper_weekdays", kind: "selected_weekdays"}],
        sample_events: [
          %{
            key: "set_1",
            event_type_key: "workout_set",
            item_links: %{exercise: "chest_press"},
            payload: %{reps: 10}
          }
        ]
      }

      assert Diagnostics.validate_plan_draft(draft) == []
    end
  end

  defp diagnostic(diagnostics, code) do
    Enum.find(diagnostics, &(&1.code == code)) || flunk("Missing diagnostic #{inspect(code)}")
  end
end
