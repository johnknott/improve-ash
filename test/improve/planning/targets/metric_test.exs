defmodule Improve.Planning.Targets.MetricTest do
  use ExUnit.Case, async: true

  alias Improve.Planning.Targets.Evaluation
  alias Improve.Planning.Targets.Metric

  describe "completion/1" do
    test "completes when a same-day linked event records a metric value" do
      track =
        track(%{
          target: %{
            "type" => "metric",
            "metric" => "Bodyweight",
            "unit" => "kg",
            "quantity_path" => "payload.value"
          }
        })

      linked =
        event(%{
          id: "event-1",
          track_id: track.id,
          payload: %{"value" => 82.5}
        })

      other_track =
        event(%{
          id: "event-2",
          track_id: "other-track",
          payload: %{"value" => 80.0}
        })

      assert {:ok, completion, []} =
               Metric.completion(%Evaluation{
                 track: track,
                 date: ~D[2026-06-22],
                 journal_events: [other_track, linked]
               })

      assert completion.status == :completed
      assert completion.completed_events == [linked]
      assert completion.progress.recorded_value == 82.5
      assert completion.progress.unit == "kg"
      assert completion.progress.completed_event_ids == ["event-1"]
      assert completion.progress.label == "Recorded 82.5 kg"
    end

    test "stays incomplete when linked events do not record a value" do
      track =
        track(%{
          target: %{
            "mode" => "metric",
            "metric_name" => "Weight",
            "quantity_path" => "payload.value"
          }
        })

      assert {:ok, completion, []} =
               Metric.completion(%Evaluation{
                 track: track,
                 date: ~D[2026-06-22],
                 journal_events: [event(%{track_id: track.id, payload: %{}})]
               })

      assert completion.status == :incomplete
      assert completion.completed_events == []
      assert completion.progress.recorded_value == nil
    end
  end

  defp track(attrs) do
    Map.merge(
      %{
        id: "track-1",
        plan_id: "plan-1",
        event_type_id: "event-type-1",
        key: "bodyweight",
        name: "Bodyweight",
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
        unit: nil,
        payload: %{}
      },
      attrs
    )
  end
end
