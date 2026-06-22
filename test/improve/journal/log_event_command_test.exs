defmodule Improve.Journal.LogEventCommandTest do
  use ExUnit.Case, async: true

  alias Improve.Journal.LogEventCommand
  alias Improve.Journal.LogEventCommand.Idempotency
  alias Improve.Journal.LogEventCommand.ItemLink

  describe "from_attrs/1" do
    test "normalizes the generic event logging command shape" do
      assert {:ok, command} =
               LogEventCommand.from_attrs(%{
                 plan_id: "plan-1",
                 event_type_id: "event-type-1",
                 session_occurrence_id: "occurrence-1",
                 slot_result_id: "slot-1",
                 direct_goal_id: "goal-1",
                 replaces_event_instance_id: "event-1",
                 replaces_item_effect_id: "effect-1",
                 effective_at: ~U[2026-06-22 12:00:00Z],
                 recorded_at: ~U[2026-06-22 12:05:00Z],
                 summary: "Chest Press completed",
                 quantity: Decimal.new("3"),
                 unit: "sets",
                 payload: %{"reps" => [10, 10, 8]},
                 note: "Felt strong",
                 origin: :offline_sync,
                 item_links: [
                   %{role: "exercise", item_id: "item-1", metadata: %{"source" => "slot"}},
                   %{"role" => "machine", "item_id" => "item-2"}
                 ],
                 idempotency: %{
                   client_event_id: "client-event-1",
                   client_operation_id: "client-op-1",
                   client_device_id: "device-1",
                   idempotency_key: "idem-1"
                 }
               })

      assert command.plan_id == "plan-1"
      assert command.event_type_id == "event-type-1"
      assert command.session_occurrence_id == "occurrence-1"
      assert command.slot_result_id == "slot-1"
      assert command.direct_goal_id == "goal-1"
      assert command.replaces_event_instance_id == "event-1"
      assert command.replaces_item_effect_id == "effect-1"
      assert command.origin == :offline_sync
      assert command.payload == %{"reps" => [10, 10, 8]}

      assert command.item_links == [
               %ItemLink{role: "exercise", item_id: "item-1", metadata: %{"source" => "slot"}},
               %ItemLink{role: "machine", item_id: "item-2", metadata: %{}}
             ]

      assert command.idempotency == %Idempotency{
               client_event_id: "client-event-1",
               client_operation_id: "client-op-1",
               client_device_id: "device-1",
               idempotency_key: "idem-1"
             }
    end

    test "defaults optional fields for simple manual logging" do
      assert {:ok, command} =
               LogEventCommand.from_attrs(%{
                 plan_id: "plan-1",
                 event_type_id: "event-type-1",
                 effective_at: ~U[2026-06-22 12:00:00Z],
                 recorded_at: ~U[2026-06-22 12:05:00Z],
                 summary: "Read 20 minutes"
               })

      assert command.origin == :manual
      assert command.payload == %{}
      assert command.item_links == []
      assert command.idempotency == nil
    end

    test "returns plain diagnostics for missing required fields and invalid children" do
      assert {:error, diagnostics} =
               LogEventCommand.from_attrs(%{
                 origin: "other",
                 item_links: [
                   %{item_id: "item-1"},
                   %{role: "book"},
                   "bad"
                 ],
                 idempotency: %{}
               })

      assert diagnostics == [
               "Plan is required.",
               "Event type is required.",
               "Effective time is required.",
               "Recorded time is required.",
               "Summary is required.",
               ~s(Origin "other" is not supported.),
               "Item link 1 role is required.",
               "Item link 2 item is required.",
               "Item link 3 must be a map.",
               "Idempotency requires a client device ID.",
               "Idempotency requires a client operation ID or idempotency key."
             ]
    end

    test "extracts event attrs without command-only data" do
      command =
        LogEventCommand.from_attrs!(%{
          plan_id: "plan-1",
          event_type_id: "event-type-1",
          effective_at: ~U[2026-06-22 12:00:00Z],
          recorded_at: ~U[2026-06-22 12:05:00Z],
          summary: "Logged",
          item_links: [%{role: "item", item_id: "item-1"}],
          idempotency: %{
            client_event_id: "client-event-1",
            client_operation_id: "client-op-1",
            client_device_id: "device-1",
            idempotency_key: "idem-1"
          }
        })

      event_attrs = LogEventCommand.to_event_attrs(command)

      refute Map.has_key?(event_attrs, :item_links)
      refute Map.has_key?(event_attrs, :idempotency)
      refute Map.has_key?(event_attrs, :replaces_item_effect_id)
      assert event_attrs.plan_id == "plan-1"
      assert event_attrs.summary == "Logged"
      assert event_attrs.client_event_id == "client-event-1"
      assert event_attrs.client_operation_id == "client-op-1"
      assert event_attrs.client_device_id == "device-1"
      assert event_attrs.idempotency_key == "idem-1"
    end
  end
end
