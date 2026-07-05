defmodule Improve.Sessions.StartProjectedSessionTest do
  use Improve.DataCase, async: true

  alias Improve.Accounts
  alias Improve.Fixtures.GymPlan
  alias Improve.Plans
  alias Improve.Sessions

  describe "start_projected_session!/2" do
    test "persists a projected gym session and preserves recommended versus actual choices" do
      user =
        Accounts.create_user!(%{
          email: "start-gym-session@example.com",
          full_name: "Start Gym Session"
        })

      %{plan: plan, session_slots: session_slots} =
        GymPlan.install!(user, starts_on: ~D[2026-06-22])

      items =
        Plans.list_items!(actor: user, query: [filter: [plan_id: plan.id]])
        |> Map.new(&{&1.key, &1})

      session_slots
      |> Enum.find(&(&1.key == "cardio"))
      |> Plans.update_session_slot!(
        %{
          rules: %{
            "default_payload" => %{"duration_minutes" => 15, "intensity" => "easy"}
          }
        },
        actor: user
      )

      projection =
        Plans.project_today!(
          plan,
          actor: user,
          date: ~D[2026-06-22],
          recent_item_ids: [items["bike"].id]
        )

      [projected_occurrence] = projection.projected_session_occurrences

      cardio_recommendation =
        Enum.find(projected_occurrence.recommendations, &(&1.slot_key == "cardio"))

      assert [%{item_name: "Rower", item_id: rower_id}] = cardio_recommendation.recommended_items

      assert [%{suggested_payload: %{"duration_minutes" => 15, "intensity" => "easy"}}] =
               cardio_recommendation.recommended_items

      assert [%{reason: reason, source: "manual_rule"}] =
               cardio_recommendation.recommended_items

      assert reason == "The plan's usual starting point."

      result =
        Sessions.start_projected_session!(
          projected_occurrence,
          actor: user,
          started_at: ~U[2026-06-22 12:00:00Z],
          actual_item_ids_by_slot_key: %{"cardio" => [items["bike"].id]}
        )

      assert result.session_occurrence.plan_id == plan.id
      assert result.session_occurrence.status == :started
      assert result.session_occurrence.started_at == ~U[2026-06-22 12:00:00.000000Z]

      assert result.session_occurrence.recommendation_snapshot["session_template_name"] ==
               "Upper-biased gym visit"

      [cardio_snapshot] =
        Enum.filter(
          result.session_occurrence.recommendation_snapshot["recommendations"],
          &(&1["slot_key"] == "cardio")
        )

      assert [
               %{
                 "suggested_payload" => %{"duration_minutes" => 15, "intensity" => "easy"},
                 "source" => "manual_rule",
                 "previous_event_ids" => []
               }
             ] = cardio_snapshot["recommended_items"]

      assert {:ok, [persisted_occurrence]} = Sessions.list_session_occurrences(actor: user)
      assert persisted_occurrence.id == result.session_occurrence.id

      assert {:ok, slot_results} = Sessions.list_slot_results(actor: user)
      assert length(slot_results) == 5

      swapped_cardio =
        Enum.find(slot_results, fn slot_result ->
          slot_result.recommended_item_id == rower_id and
            slot_result.actual_item_id == items["bike"].id
        end)

      assert swapped_cardio.session_occurrence_id == persisted_occurrence.id
      assert swapped_cardio.status == :swapped

      assert swapped_cardio.suggested_payload == %{
               "duration_minutes" => 15,
               "intensity" => "easy"
             }

      assert swapped_cardio.actual_payload == %{}
    end
  end
end
