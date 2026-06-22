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
        schema: "improve.plan_draft",
        version: 1,
        key: "minimal",
        name: "Minimal Plan",
        item_types: [%{key: "exercise", name: "Exercise"}],
        items: [%{key: "chest_press", name: "Chest Press", item_type_key: "exercise"}],
        pools: [%{key: "push", name: "Push"}],
        session_templates: [
          %{
            key: "upper",
            name: "Upper",
            slots: [%{key: "press", name: "Press", pool_key: "push"}]
          }
        ],
        event_types: [
          %{
            key: "workout_set",
            name: "Workout Set",
            item_link_roles: %{
              roles: [%{role: "exercise", item_type_key: "exercise", required: true}]
            },
            effect_rules: %{rules: []}
          }
        ],
        schedules: [
          %{
            key: "upper_weekdays",
            owner_type: "session_template",
            owner_key: "upper",
            kind: "selected_weekdays",
            starts_on: ~D[2026-06-22]
          }
        ],
        sample_events: [
          %{
            key: "set_1",
            event_type_key: "workout_set",
            effective_at: ~U[2026-06-22 12:00:00Z],
            item_links: %{exercise: "chest_press"},
            payload: %{reps: 10}
          }
        ]
      }

      assert Diagnostics.validate_plan_draft(draft) == []
    end

    test "returns diagnostics for required schema fields before import" do
      draft = %{
        schema: "improve.plan_draft",
        version: 1,
        item_types: [
          %{key: "exercise"}
        ],
        items: [
          %{key: "chest_press", name: "Chest Press"}
        ],
        event_types: [
          %{name: "Workout Set"}
        ],
        session_templates: [
          %{
            key: "upper",
            name: "Upper",
            slots: [
              %{key: "press", name: "Press"}
            ]
          }
        ],
        direct_goals: [
          %{key: "sets", name: "Sets"}
        ],
        schedules: [
          %{
            key: "daily_sets",
            owner_type: "direct_goal",
            owner_key: "sets",
            kind: "every_day"
          }
        ],
        sample_events: [
          %{key: "set_1", event_type_key: "workout_set"}
        ]
      }

      required_paths =
        draft
        |> Diagnostics.validate_plan_draft()
        |> Enum.filter(&(&1.code == :missing_required_field))
        |> Enum.map(& &1.path)

      assert ["key"] in required_paths
      assert ["name"] in required_paths
      assert ["item_types", "exercise", "name"] in required_paths
      assert ["items", "chest_press", "item_type_key"] in required_paths
      assert ["event_types", "0", "key"] in required_paths
      assert ["direct_goals", "sets", "event_type_key"] in required_paths
      assert ["schedules", "daily_sets", "starts_on"] in required_paths
      assert ["sample_events", "set_1", "effective_at"] in required_paths
      assert ["session_templates", "upper", "slots", "press", "pool_key"] in required_paths
    end

    test "returns diagnostics for stable-key references and policy shape mistakes" do
      draft = %{
        item_types: [%{key: "book", name: "Book"}],
        items: [
          %{key: "deep_work", name: "Deep Work", item_type_key: "missing_type"}
        ],
        pools: [
          %{key: "reading_pool", name: "Reading", item_keys: ["missing_book"]}
        ],
        environments: [
          %{key: "library", name: "Library", available_item_keys: ["missing_book"]}
        ],
        event_types: [
          %{
            key: "read_pages",
            item_link_roles: %{
              roles: [
                %{role: "book", item_type_key: "book", required: true},
                %{role: "book", item_type_key: "book", required: false}
              ]
            },
            effect_rules: %{rules: [%{role: "missing_role", effect_type: "add_quantity"}]}
          }
        ],
        session_templates: [
          %{key: "reading_session", environment_key: "missing_environment"}
        ],
        direct_goals: [
          %{
            key: "read_twenty",
            event_type_key: "missing_event_type",
            target: %{"quantity" => 20}
          }
        ],
        schedules: [
          %{
            key: "bad_owner",
            owner_type: "direct_goal",
            owner_key: "missing_goal",
            kind: "every_day"
          },
          %{
            key: "bad_weekdays",
            owner_type: "direct_goal",
            owner_key: "read_twenty",
            kind: "times_per_week",
            rules: %{"allowed_weekdays" => "monday"}
          }
        ],
        sample_events: [
          %{
            key: "sample",
            event_type_key: "missing_event_type",
            direct_goal_key: "missing_goal"
          }
        ]
      }

      diagnostics = Diagnostics.validate_plan_draft(draft)

      assert diagnostic(diagnostics, :missing_item_type).ref == "missing_type"
      assert diagnostic(diagnostics, :missing_item).ref == "missing_book"
      assert diagnostic(diagnostics, :missing_environment).ref == "missing_environment"
      assert diagnostic(diagnostics, :missing_event_type).ref == "missing_event_type"
      assert diagnostic(diagnostics, :missing_schedule_owner).ref == "missing_goal"
      assert diagnostic(diagnostics, :missing_direct_goal).ref == "missing_goal"
      assert diagnostic(diagnostics, :duplicate_item_link_role).ref == "book"
      assert diagnostic(diagnostics, :effect_rule_unknown_role).ref == "missing_role"
      assert diagnostic(diagnostics, :direct_goal_target_unit_missing).ref == "read_twenty"
      assert diagnostic(diagnostics, :unsupported_schedule_rule_shape).ref == "bad_weekdays"
    end
  end

  defp diagnostic(diagnostics, code) do
    Enum.find(diagnostics, &(&1.code == code)) || flunk("Missing diagnostic #{inspect(code)}")
  end
end
