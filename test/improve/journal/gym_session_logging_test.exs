defmodule Improve.Journal.GymSessionLoggingTest do
  use Improve.DataCase, async: true

  alias Improve.Accounts
  alias Improve.CommandError
  alias Improve.Fixtures.GymPlan
  alias Improve.Journal
  alias Improve.Plans
  alias Improve.Sessions

  describe "logging workout events for a started gym session" do
    test "creates journal events, links items, links slot results, and completes the session" do
      user =
        Accounts.create_user!(%{
          email: "log-gym-session@example.com",
          full_name: "Log Gym Session"
        })

      %{plan: plan} = GymPlan.install!(user, starts_on: ~D[2026-06-22])

      items =
        Plans.list_items!(actor: user, query: [filter: [plan_id: plan.id]])
        |> Map.new(&{&1.key, &1})

      event_types =
        Plans.list_event_types!(actor: user, query: [filter: [plan_id: plan.id]])
        |> Map.new(&{&1.key, &1})

      projection =
        Plans.project_today!(
          plan,
          actor: user,
          date: ~D[2026-06-22],
          recent_item_ids: [items["bike"].id]
        )

      [projected_occurrence] = projection.projected_session_occurrences

      started =
        Sessions.start_projected_session!(
          projected_occurrence,
          actor: user,
          started_at: ~U[2026-06-22 12:00:00Z],
          actual_item_ids_by_slot_key: %{"cardio" => [items["bike"].id]}
        )

      slot_results_by_item_id =
        started.slot_results
        |> Map.new(&{&1.actual_item_id, &1})

      chest_press_log =
        Journal.log_session_item_event!(
          %{
            session_occurrence: started.session_occurrence,
            slot_result: slot_results_by_item_id[items["chest_press"].id],
            event_type: event_types["workout_exercise_performed"],
            item: items["chest_press"],
            role: "exercise",
            effective_at: ~U[2026-06-22 12:10:00Z],
            recorded_at: ~U[2026-06-22 12:11:00Z],
            summary: "Chest Press, 3 sets of 10 at 45 kg, RPE 8",
            payload: %{"sets" => 3, "reps" => 10, "load" => 45, "load_unit" => "kg", "rpe" => 8}
          },
          actor: user
        )

      lat_pulldown_log =
        Journal.log_session_item_event!(
          %{
            session_occurrence: started.session_occurrence,
            slot_result: slot_results_by_item_id[items["lat_pulldown"].id],
            event_type: event_types["workout_exercise_performed"],
            item: items["lat_pulldown"],
            role: "exercise",
            effective_at: ~U[2026-06-22 12:30:00Z],
            recorded_at: ~U[2026-06-22 12:31:00Z],
            summary: "Lat Pulldown, 3 sets of 10 at 50 kg, RPE 8",
            payload: %{"sets" => 3, "reps" => 10, "load" => 50, "load_unit" => "kg", "rpe" => 8}
          },
          actor: user
        )

      bike_log =
        Journal.log_session_item_event!(
          %{
            session_occurrence: started.session_occurrence,
            slot_result: slot_results_by_item_id[items["bike"].id],
            event_type: event_types["cardio_block_performed"],
            item: items["bike"],
            role: "machine",
            effective_at: ~U[2026-06-22 12:50:00Z],
            recorded_at: ~U[2026-06-22 12:51:00Z],
            summary: "Bike, 20 minutes, moderate effort",
            quantity: Decimal.new(20),
            unit: "minutes",
            payload: %{"duration_minutes" => 20, "intensity" => "moderate"}
          },
          actor: user
        )

      completed_occurrence =
        Sessions.complete_session_occurrence!(
          started.session_occurrence,
          %{completed_at: ~U[2026-06-22 13:15:00Z]},
          actor: user
        )

      assert completed_occurrence.status == :completed

      assert chest_press_log.event_item_link.item_id == items["chest_press"].id
      assert lat_pulldown_log.event_item_link.item_id == items["lat_pulldown"].id
      assert bike_log.event_item_link.item_id == items["bike"].id

      assert chest_press_log.slot_result.event_instance_id == chest_press_log.event.id
      assert lat_pulldown_log.slot_result.event_instance_id == lat_pulldown_log.event.id
      assert bike_log.slot_result.event_instance_id == bike_log.event.id
      assert bike_log.slot_result.status == :swapped

      journal = Journal.read_journal!(plan, actor: user)

      assert Enum.map(journal, & &1.summary) == [
               "Chest Press, 3 sets of 10 at 45 kg, RPE 8",
               "Lat Pulldown, 3 sets of 10 at 50 kg, RPE 8",
               "Bike, 20 minutes, moderate effort"
             ]

      assert [%{id: chest_press_event_id}] =
               Journal.item_history!(items["chest_press"], actor: user)

      assert chest_press_event_id == chest_press_log.event.id

      session_slot_results = Sessions.list_slot_results!(actor: user)
      assert Enum.count(session_slot_results, & &1.event_instance_id) == 3
    end

    test "uses generic event contract validation for session item logs" do
      user =
        Accounts.create_user!(%{
          email: "log-gym-session-contract@example.com",
          full_name: "Log Gym Session Contract"
        })

      %{plan: plan} = GymPlan.install!(user, starts_on: ~D[2026-06-22])

      items =
        Plans.list_items!(actor: user, query: [filter: [plan_id: plan.id]])
        |> Map.new(&{&1.key, &1})

      event_types =
        Plans.list_event_types!(actor: user, query: [filter: [plan_id: plan.id]])
        |> Map.new(&{&1.key, &1})

      projection = Plans.project_today!(plan, actor: user, date: ~D[2026-06-22])
      [projected_occurrence] = projection.projected_session_occurrences

      started =
        Sessions.start_projected_session!(
          projected_occurrence,
          actor: user,
          started_at: ~U[2026-06-22 12:00:00Z]
        )

      slot_result =
        Enum.find(started.slot_results, &(&1.actual_item_id == items["chest_press"].id))

      error =
        assert_raise CommandError, fn ->
          Journal.log_session_item_event!(
            %{
              session_occurrence: started.session_occurrence,
              slot_result: slot_result,
              event_type: event_types["workout_exercise_performed"],
              item: items["chest_press"],
              role: "exercise",
              effective_at: ~U[2026-06-22 12:10:00Z],
              recorded_at: ~U[2026-06-22 12:11:00Z],
              summary: "Chest Press without required payload"
            },
            actor: user
          )
        end

      assert error.operation == :log_session_item_event
      assert error.category == :invalid_command
      assert "Event type requires payload field sets." in error.details
      assert "Event type requires payload field reps." in error.details
      assert Journal.read_journal!(plan, actor: user) == []
    end
  end
end
