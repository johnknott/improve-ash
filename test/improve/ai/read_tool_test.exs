defmodule Improve.Ai.ReadToolTest do
  use Improve.DataCase, async: true

  alias Improve.Accounts
  alias Improve.Fixtures.GymPlan
  alias Improve.Fixtures.VialPlan
  alias Improve.Journal
  alias Improve.Plans

  describe "AshAI read tools" do
    test "exposes only the read-only spike tools" do
      tools = tools_by_name(actor: user!("ai-tools-list@example.com"))

      assert Map.keys(tools) == [
               "get_item_state",
               "get_plan_summary",
               "get_recent_journal_events",
               "project_today"
             ]

      assert Enum.all?(Map.values(tools), &(&1.action.type == :action))
    end

    test "projects today's work and returns derived vial state through AshAI execution" do
      user = user!("ai-tools-owner@example.com")
      other_user = user!("ai-tools-other@example.com")

      %{plan: gym_plan} = GymPlan.install!(user, starts_on: ~D[2026-06-22])
      %{plan: vial_plan} = VialPlan.install!(user, starts_on: ~D[2026-06-22])

      vial_items =
        Plans.list_items!(actor: user, query: [filter: [plan_id: vial_plan.id]])
        |> Map.new(&{&1.key, &1})

      vial_event_types =
        Plans.list_event_types!(actor: user, query: [filter: [plan_id: vial_plan.id]])
        |> Map.new(&{&1.key, &1})

      Journal.log_linked_item_event!(
        %{
          plan: vial_plan,
          event_type: vial_event_types["take_dose"],
          linked_item: vial_items["retatrutide_vial_1"],
          role: "source_vial",
          quantity: 250,
          unit: "mcg",
          effective_at: ~U[2026-06-22 08:00:00Z],
          recorded_at: ~U[2026-06-22 08:01:00Z],
          summary: "Dose recorded from Retatrutide vial 1"
        },
        actor: user
      )

      tools = tools_by_name(actor: user)

      projection =
        execute_tool!(tools["project_today"], user, %{
          "plan_id" => gym_plan.id,
          "date" => "2026-06-22"
        })

      assert projection["plan_id"] == gym_plan.id
      assert projection["date"] == "2026-06-22"

      assert [%{"session_template_name" => "Upper-biased gym visit"}] =
               projection["projected_session_occurrences"]

      assert [
               %{
                 "kind" => "session",
                 "status" => "planned",
                 "owner_type" => "session_template",
                 "title" => "Upper-biased gym visit",
                 "session_occurrence" => %{
                   "session_template_name" => "Upper-biased gym visit"
                 }
               }
             ] = projection["projected_work"]

      assert projection["input_summary"]["session_templates"] == 1
      assert projection["input_summary"]["direct_goals"] == 0

      summary = execute_tool!(tools["get_plan_summary"], user, %{"plan_id" => gym_plan.id})

      assert summary["items"] == 8
      assert summary["session_slots"] == 3

      state =
        execute_tool!(tools["get_item_state"], user, %{
          "item_id" => vial_items["retatrutide_vial_1"].id
        })

      assert state["item_id"] == vial_items["retatrutide_vial_1"].id
      assert state["calculated_state"]["current_quantity"] == "4750"

      assert [%{"effect_type" => "subtract_quantity", "quantity" => "250"}] =
               state["active_effects"]

      journal =
        execute_tool!(tools["get_recent_journal_events"], user, %{
          "plan_id" => vial_plan.id,
          "limit" => 5
        })

      assert [
               %{
                 "summary" => "Dose recorded from Retatrutide vial 1",
                 "quantity" => "250",
                 "unit" => "mcg"
               }
             ] = journal["events"]

      assert {:error, error_text} =
               AshAi.Tools.execute(
                 tools["get_item_state"],
                 %{"input" => %{"item_id" => vial_items["retatrutide_vial_1"].id}},
                 %{actor: other_user}
               )

      assert error_text =~ "could not be found"
    end

    test "projects direct goal work through AshAI execution" do
      user = user!("ai-direct-goal@example.com")
      plan = reading_plan!(user)
      event_type = reading_event_type!(user, plan)
      direct_goal = reading_direct_goal!(user, plan, event_type)
      reading_schedule!(user, plan, direct_goal)

      log =
        Journal.log_generic_event!(
          %{
            plan_id: plan.id,
            event_type_id: event_type.id,
            direct_goal_id: direct_goal.id,
            effective_at: ~U[2026-06-22 20:00:00Z],
            recorded_at: ~U[2026-06-22 20:01:00Z],
            summary: "Read 25 pages",
            quantity: 25,
            unit: "pages"
          },
          actor: user
        )

      tools = tools_by_name(actor: user)

      projection =
        execute_tool!(tools["project_today"], user, %{
          "plan_id" => plan.id,
          "date" => "2026-06-22"
        })

      assert [
               %{
                 "kind" => "direct_goal",
                 "status" => "completed",
                 "title" => "Read 20 pages",
                 "direct_goal" => %{
                   "direct_goal_id" => direct_goal_id,
                   "completed_event_ids" => [completed_event_id]
                 }
               }
             ] = projection["projected_work"]

      assert direct_goal_id == direct_goal.id
      assert completed_event_id == log.event.id

      summary = execute_tool!(tools["get_plan_summary"], user, %{"plan_id" => plan.id})

      assert summary["direct_goals"] == 1
    end
  end

  defp user!(email) do
    Accounts.create_user!(%{
      email: email,
      full_name: "AI Tool User"
    })
  end

  defp tools_by_name(opts) do
    opts
    |> Keyword.put(:otp_app, :improve)
    |> AshAi.exposed_tools()
    |> Map.new(&{to_string(&1.name), &1})
  end

  defp execute_tool!(tool, actor, input) do
    assert {:ok, json_result, _raw_result} =
             AshAi.Tools.execute(tool, %{"input" => input}, %{actor: actor})

    Jason.decode!(json_result)
  end

  defp reading_plan!(user) do
    Plans.create_plan!(
      %{
        name: "Reading",
        intention: "Track reading",
        starts_on: ~D[2026-06-22],
        ends_on: ~D[2026-07-20]
      },
      actor: user
    )
  end

  defp reading_event_type!(user, plan) do
    Plans.create_event_type!(
      %{
        plan_id: plan.id,
        key: "read_pages",
        name: "Read Pages"
      },
      actor: user
    )
  end

  defp reading_direct_goal!(user, plan, event_type) do
    Plans.create_direct_goal!(
      %{
        plan_id: plan.id,
        event_type_id: event_type.id,
        key: "read_twenty_pages",
        name: "Read 20 pages",
        target: %{"quantity" => 20, "unit" => "pages"},
        completion_policy: %{"mode" => "at_least_target"},
        missed_policy: %{"mode" => "miss_if_no_event_by_end_of_day"}
      },
      actor: user
    )
  end

  defp reading_schedule!(user, plan, direct_goal) do
    Plans.create_schedule!(
      %{
        plan_id: plan.id,
        owner_type: :direct_goal,
        owner_id: direct_goal.id,
        kind: :every_day,
        starts_on: ~D[2026-06-22]
      },
      actor: user
    )
  end
end
