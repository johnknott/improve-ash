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

      Journal.log_dose_event!(
        %{
          plan: vial_plan,
          event_type: vial_event_types["take_dose"],
          source_vial: vial_items["retatrutide_vial_1"],
          amount: 250,
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
end
