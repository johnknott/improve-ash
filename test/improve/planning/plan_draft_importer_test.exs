defmodule Improve.Planning.PlanDraftImporterTest do
  use Improve.DataCase, async: true

  alias Improve.Accounts
  alias Improve.Fixtures.GymPlan
  alias Improve.Journal
  alias Improve.Plans

  describe "import_plan_draft/2" do
    test "imports an exported gym draft as a user-owned editable copy" do
      source_user = user!("import-source@example.com")
      target_user = user!("import-target@example.com")
      %{plan: source_plan} = GymPlan.install!(source_user, starts_on: ~D[2026-06-22])
      draft = Plans.export_plan_draft!(source_plan, actor: source_user)

      assert {:ok, result} = Plans.import_plan_draft(draft, actor: target_user)

      assert result.plan.user_id == target_user.id
      assert result.plan.status == :draft
      assert result.plan.source_kind == :imported
      assert result.plan.source_key == "gym"
      assert map_size(result.item_types) == 3
      assert map_size(result.items) == 8
      assert map_size(result.pools) == 3
      assert map_size(result.environments) == 1
      assert map_size(result.event_types) == 2
      assert map_size(result.session_templates) == 1
      assert length(result.schedules) == 1

      imported_draft = Plans.export_plan_draft!(result.plan, actor: target_user)

      assert Enum.map(imported_draft.items, & &1.key) == Enum.map(draft.items, & &1.key)

      assert Enum.map(imported_draft.pools, &{&1.key, &1.item_keys}) ==
               Enum.map(draft.pools, &{&1.key, &1.item_keys})

      assert [
               %{
                 owner_type: "session_template",
                 owner_key: "upper_biased_gym_visit",
                 kind: "times_per_week"
               }
             ] = imported_draft.schedules

      assert {:ok, []} =
               Plans.list_plans(actor: source_user, query: [filter: [id: result.plan.id]])
    end

    test "imports direct goals and their schedules from stable keys" do
      user = user!("import-direct-goal@example.com")

      draft = %{
        key: "reading",
        name: "Reading",
        intention: "Track reading",
        starts_on: "2026-06-22",
        ends_on: "2026-07-20",
        event_types: [
          %{key: "read_pages", name: "Read Pages"}
        ],
        direct_goals: [
          %{
            key: "read_twenty_pages",
            name: "Read 20 pages",
            event_type_key: "read_pages",
            target: %{"quantity" => 20, "unit" => "pages"},
            completion_policy: %{"mode" => "at_least_target"},
            missed_policy: %{"mode" => "miss_if_no_event_by_end_of_day"}
          }
        ],
        schedules: [
          %{
            key: "read_daily",
            owner_type: "direct_goal",
            owner_key: "read_twenty_pages",
            kind: "every_day",
            starts_on: "2026-06-22"
          }
        ]
      }

      assert {:ok, result} = Plans.import_plan_draft(draft, actor: user)

      assert Map.has_key?(result.direct_goals, "read_twenty_pages")
      assert [schedule] = result.schedules
      assert schedule.owner_type == :direct_goal
      assert schedule.owner_id == result.direct_goals["read_twenty_pages"].id

      assert {:ok, projection} =
               Plans.project_today(result.plan, actor: user, date: ~D[2026-06-22])

      assert [%{kind: :direct_goal, status: :planned}] = projection.projected_work
      assert {:ok, []} = Journal.read_journal(result.plan, actor: user)
    end

    test "returns diagnostics without partial installs when references are invalid" do
      user = user!("import-invalid@example.com")

      draft = %{
        key: "bad",
        name: "Bad Draft",
        intention: "Should not persist",
        starts_on: "2026-06-22",
        ends_on: "2026-07-20",
        session_templates: [
          %{
            key: "upper",
            name: "Upper",
            slots: [%{key: "push", name: "Push", pool_key: "missing_pool"}]
          }
        ]
      }

      assert {:error, diagnostics} = Plans.import_plan_draft(draft, actor: user)
      assert Enum.any?(diagnostics, &(&1.code == :missing_pool))
      assert {:ok, []} = Plans.list_plans(actor: user)
    end
  end

  defp user!(email) do
    Accounts.create_user!(%{
      email: email,
      full_name: "Import User"
    })
  end
end
