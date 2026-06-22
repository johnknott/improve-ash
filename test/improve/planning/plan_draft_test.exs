defmodule Improve.Planning.PlanDraftTest do
  use ExUnit.Case, async: true

  alias Improve.Planning.Diagnostics
  alias Improve.Planning.PlanDraft

  describe "schema/0" do
    test "defines the first useful portable draft shape" do
      schema = PlanDraft.schema()

      assert schema.schema == "improve.plan_draft"
      assert schema.version == PlanDraft.current_version()

      assert MapSet.new(Map.keys(schema.collections)) ==
               MapSet.new([
                 :direct_goals,
                 :environments,
                 :event_types,
                 :item_types,
                 :items,
                 :pools,
                 :sample_events,
                 :schedules,
                 :session_templates
               ])

      assert schema.collections.items.references == %{item_type_key: :item_types}
      assert schema.collections.pools.references == %{item_keys: :items}
      assert schema.collections.environments.references == %{available_item_keys: :items}

      assert schema.collections.session_templates.references == %{
               environment_key: :environments
             }

      assert schema.collections.session_templates.children.slots.references == %{pool_key: :pools}

      assert schema.collections.direct_goals.references == %{event_type_key: :event_types}

      assert schema.collections.direct_goals.policy_fields == [
               :target,
               :completion_policy,
               :missed_policy
             ]

      assert schema.collections.schedules.references == %{
               owner_key: [:session_templates, :direct_goals]
             }

      assert schema.collections.schedules.supported_owner_types == [
               :session_template,
               :direct_goal
             ]

      assert schema.collections.schedules.supported_kinds == [
               :every_day,
               :selected_weekdays,
               :times_per_week
             ]

      assert schema.collections.sample_events.references == %{
               direct_goal_key: :direct_goals,
               event_type_key: :event_types
             }
    end

    test "documents stable-key reference fields" do
      assert {:items, :item_type_key} in PlanDraft.stable_reference_fields()
      assert {:session_templates, :environment_key} in PlanDraft.stable_reference_fields()
      assert {:direct_goals, :event_type_key} in PlanDraft.stable_reference_fields()
      assert {:schedules, :owner_key} in PlanDraft.stable_reference_fields()
      assert {:sample_events, :direct_goal_key} in PlanDraft.stable_reference_fields()
    end
  end

  describe "empty/1" do
    test "builds a versioned draft skeleton with all portable sections" do
      draft = PlanDraft.empty(%{key: "reading", name: "Reading"})

      assert draft.schema == "improve.plan_draft"
      assert draft.version == 1
      assert draft.key == "reading"
      assert draft.name == "Reading"

      for collection <- PlanDraft.collection_names() do
        assert Map.fetch!(draft, collection) == []
      end
    end
  end

  describe "normalize/1" do
    test "accepts string-keyed draft maps and normalizes collection defaults" do
      draft =
        PlanDraft.normalize(%{
          "version" => "1",
          "key" => "gym",
          "name" => "Gym",
          "item_types" => %{
            "exercise" => %{"key" => "exercise", "name" => "Exercise"}
          }
        })

      assert draft.version == 1
      assert draft.key == "gym"
      assert draft.name == "Gym"
      assert draft.item_types == [%{"key" => "exercise", "name" => "Exercise"}]
      assert draft.direct_goals == []
      assert draft.schedules == []
    end
  end

  describe "diagnostics integration" do
    test "direct goals and schedules participate in keyed draft diagnostics" do
      diagnostics =
        Diagnostics.validate_plan_draft(%{
          direct_goals: [
            %{key: "read", name: "Read", event_type_key: "read_pages"},
            %{key: "read", name: "Read duplicate", event_type_key: "read_pages"}
          ],
          schedules: [
            %{
              key: "read_daily",
              owner_type: "direct_goal",
              owner_key: "read",
              kind: "every_day"
            },
            %{
              key: "read_daily",
              owner_type: "direct_goal",
              owner_key: "read",
              kind: "every_day"
            }
          ]
        })

      duplicate_refs =
        diagnostics
        |> Enum.filter(&(&1.code == :duplicate_key))
        |> Enum.map(& &1.ref)

      assert "read" in duplicate_refs
      assert "read_daily" in duplicate_refs
    end
  end
end
