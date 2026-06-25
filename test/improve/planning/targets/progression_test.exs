defmodule Improve.Planning.Targets.ProgressionTest do
  use ExUnit.Case, async: true

  alias Improve.Planning.Targets.Evaluation
  alias Improve.Planning.Targets.Progression

  describe "completion/1" do
    test "uses the start amount on the first date" do
      assert {:ok, completion, []} =
               Progression.completion(%Evaluation{
                 track: track(),
                 plan: plan(),
                 date: ~D[2026-06-22],
                 journal_events: [event(%{quantity: 1_000})]
               })

      assert completion.status == :completed
      assert completion.progress.expected_quantity == "1000"
      assert completion.progress.total_quantity == "1000"
      assert completion.progress.label == "1000 of 1000 steps expected today"
    end

    test "interpolates the middle date" do
      assert {:ok, completion, []} =
               Progression.completion(%Evaluation{
                 track: track(),
                 plan: plan(),
                 date: ~D[2026-07-06],
                 journal_events: [
                   event(%{effective_at: ~U[2026-07-06 20:00:00Z], quantity: 5_499})
                 ]
               })

      assert completion.status == :incomplete
      assert completion.progress.expected_quantity == "5500"
      assert completion.progress.total_quantity == "5499"
    end

    test "uses the end amount on the final date" do
      assert {:ok, completion, []} =
               Progression.completion(%Evaluation{
                 track: track(),
                 plan: plan(),
                 date: ~D[2026-07-20],
                 journal_events: [
                   event(%{effective_at: ~U[2026-07-20 20:00:00Z], quantity: 10_000})
                 ]
               })

      assert completion.status == :completed
      assert completion.progress.expected_quantity == "10000"
      assert completion.progress.total_quantity == "10000"
    end

    test "supports legacy progression maps inside otherwise fixed-looking targets" do
      legacy_track =
        track(%{
          target: %{
            "quantity" => 10_000,
            "unit" => "steps",
            "quantity_path" => "payload.amount",
            "progression" => %{"from" => 1_000, "to" => 10_000, "shape" => "linear"}
          }
        })

      assert {:ok, completion, []} =
               Progression.completion(%Evaluation{
                 track: legacy_track,
                 plan: plan(),
                 date: ~D[2026-07-06],
                 journal_events: [
                   event(%{
                     effective_at: ~U[2026-07-06 20:00:00Z],
                     quantity: nil,
                     payload: %{"amount" => 5_500}
                   })
                 ]
               })

      assert completion.status == :completed
      assert completion.progress.expected_quantity == "5500"
      assert completion.progress.completed_event_ids == ["event-1"]
    end
  end

  defp plan do
    %{id: "plan-1", starts_on: ~D[2026-06-22], ends_on: ~D[2026-07-20]}
  end

  defp track(attrs \\ %{}) do
    Map.merge(
      %{
        id: "track-1",
        plan_id: "plan-1",
        event_type_id: "event-type-1",
        key: "daily_steps",
        name: "Daily steps",
        target: %{
          "type" => "progression",
          "from" => 1_000,
          "to" => 10_000,
          "unit" => "steps",
          "quantity_path" => "payload.amount",
          "shape" => "linear"
        },
        completion_policy: %{},
        missed_policy: %{}
      },
      attrs
    )
  end

  defp event(attrs) do
    Map.merge(
      %{
        id: "event-1",
        track_id: "track-1",
        status: :active,
        effective_at: ~U[2026-06-22 20:00:00Z],
        quantity: nil,
        unit: "steps",
        payload: %{}
      },
      attrs
    )
  end
end
