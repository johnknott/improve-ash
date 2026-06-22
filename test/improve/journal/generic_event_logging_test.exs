defmodule Improve.Journal.GenericEventLoggingTest do
  use Improve.DataCase, async: true

  alias Improve.Accounts
  alias Improve.Fixtures.GymPlan
  alias Improve.Fixtures.VialPlan
  alias Improve.Journal
  alias Improve.Plans
  alias Improve.Sessions

  describe "log_generic_event!/2" do
    test "logs a session item event, item link, and slot result update from one command" do
      user =
        Accounts.create_user!(%{
          email: "generic-session-log@example.com",
          full_name: "Generic Session Log"
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

      log =
        Journal.log_generic_event!(
          %{
            plan_id: plan.id,
            event_type_id: event_types["workout_exercise_performed"].id,
            session_occurrence_id: started.session_occurrence.id,
            slot_result_id: slot_result.id,
            effective_at: ~U[2026-06-22 12:10:00Z],
            recorded_at: ~U[2026-06-22 12:11:00Z],
            summary: "Chest Press, 3 sets of 10 at 45 kg, RPE 8",
            payload: %{"sets" => 3, "reps" => 10, "load" => 45, "load_unit" => "kg", "rpe" => 8},
            item_links: [
              %{role: "exercise", item_id: items["chest_press"].id}
            ]
          },
          actor: user
        )

      assert log.event.summary == "Chest Press, 3 sets of 10 at 45 kg, RPE 8"
      assert [link] = log.event_item_links
      assert link.role == "exercise"
      assert link.item_id == items["chest_press"].id
      assert log.item_effects == []
      assert log.slot_result.event_instance_id == log.event.id
      assert log.slot_result.status == :completed
    end

    test "logs a stateful item event, item link, and generated effects from authored rules" do
      user =
        Accounts.create_user!(%{
          email: "generic-dose-log@example.com",
          full_name: "Generic Dose Log"
        })

      %{plan: plan} = VialPlan.install!(user, starts_on: ~D[2026-06-22])

      items =
        Plans.list_items!(actor: user, query: [filter: [plan_id: plan.id]])
        |> Map.new(&{&1.key, &1})

      event_types =
        Plans.list_event_types!(actor: user, query: [filter: [plan_id: plan.id]])
        |> Map.new(&{&1.key, &1})

      log =
        Journal.log_generic_event!(
          %{
            plan_id: plan.id,
            event_type_id: event_types["take_dose"].id,
            effective_at: ~U[2026-06-22 08:00:00Z],
            recorded_at: ~U[2026-06-22 08:01:00Z],
            summary: "Dose recorded from Retatrutide vial 1",
            quantity: 250,
            unit: "mcg",
            payload: %{
              "amount" => 250,
              "unit" => "mcg",
              "route" => "subcutaneous",
              "site" => "abdomen"
            },
            item_links: [
              %{role: "source_vial", item_id: items["retatrutide_vial_1"].id}
            ]
          },
          actor: user
        )

      assert [link] = log.event_item_links
      assert link.role == "source_vial"
      assert link.item_id == items["retatrutide_vial_1"].id

      assert [effect] = log.item_effects
      assert effect.effect_type == :subtract_quantity
      assert effect.quantity == Decimal.new(250)
      assert effect.unit == "mcg"
      assert effect.event_instance_id == log.event.id

      state = Journal.get_item_state!(items["retatrutide_vial_1"], actor: user)

      assert Decimal.equal?(state.calculated_state.current_quantity, Decimal.new(4750))
      assert Enum.map(state.active_effects, & &1.id) == [effect.id]
    end

    test "idempotently returns the original event for repeated offline submissions" do
      user =
        Accounts.create_user!(%{
          email: "generic-idempotent-log@example.com",
          full_name: "Generic Idempotent Log"
        })

      %{plan: plan} = VialPlan.install!(user, starts_on: ~D[2026-06-22])

      items =
        Plans.list_items!(actor: user, query: [filter: [plan_id: plan.id]])
        |> Map.new(&{&1.key, &1})

      event_types =
        Plans.list_event_types!(actor: user, query: [filter: [plan_id: plan.id]])
        |> Map.new(&{&1.key, &1})

      attrs = %{
        plan_id: plan.id,
        event_type_id: event_types["take_dose"].id,
        effective_at: ~U[2026-06-22 08:00:00Z],
        recorded_at: ~U[2026-06-22 08:01:00Z],
        summary: "Offline dose recorded from Retatrutide vial 1",
        quantity: 250,
        unit: "mcg",
        payload: %{
          "amount" => 250,
          "unit" => "mcg",
          "route" => "subcutaneous",
          "site" => "abdomen"
        },
        origin: :offline_sync,
        item_links: [
          %{role: "source_vial", item_id: items["retatrutide_vial_1"].id}
        ],
        idempotency: %{
          client_event_id: "client-event-1",
          client_operation_id: "client-operation-1",
          client_device_id: "device-1",
          idempotency_key: "idempotency-1"
        }
      }

      first = Journal.log_generic_event!(attrs, actor: user)
      second = Journal.log_generic_event!(attrs, actor: user)

      assert first.idempotency_status == :accepted
      assert second.idempotency_status == :duplicate
      assert second.event.id == first.event.id
      assert second.event.client_event_id == "client-event-1"
      assert second.event.client_operation_id == "client-operation-1"
      assert second.event.client_device_id == "device-1"
      assert second.event.idempotency_key == "idempotency-1"

      assert Enum.map(second.event_item_links, & &1.id) ==
               Enum.map(first.event_item_links, & &1.id)

      assert Enum.map(second.item_effects, & &1.id) == Enum.map(first.item_effects, & &1.id)

      events = Journal.read_journal!(plan, actor: user)
      effects = Journal.list_item_effects!(actor: user, query: [filter: [plan_id: plan.id]])

      assert Enum.map(events, & &1.id) == [first.event.id]
      assert Enum.map(effects, & &1.event_instance_id) == [first.event.id]
    end

    test "returns command diagnostics before starting persistence" do
      user =
        Accounts.create_user!(%{
          email: "generic-command-error@example.com",
          full_name: "Generic Command Error"
        })

      assert {:error, diagnostics} = Journal.log_generic_event(%{}, actor: user)

      assert diagnostics == [
               "Plan is required.",
               "Event type is required.",
               "Effective time is required.",
               "Recorded time is required.",
               "Summary is required."
             ]
    end
  end
end
