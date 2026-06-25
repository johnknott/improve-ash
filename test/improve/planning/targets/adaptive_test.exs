defmodule Improve.Planning.Targets.AdaptiveTest do
  use ExUnit.Case, async: true

  alias Improve.Planning.Targets.Adaptive
  alias Improve.Planning.Targets.Evaluation

  describe "completion/1" do
    test "completes when same-day linked events record all configured adaptive fields" do
      track = track()

      linked =
        event(%{
          id: "event-1",
          track_id: track.id,
          payload: %{"sets" => 3, "reps" => 10, "load" => 45, "effort" => "steady"}
        })

      assert {:ok, completion, []} =
               Adaptive.completion(%Evaluation{
                 track: track,
                 date: ~D[2026-06-22],
                 journal_events: [linked]
               })

      assert completion.status == :completed
      assert completion.completed_events == [linked]
      assert completion.progress.required_fields == ["sets", "reps", "load", "effort"]
      assert completion.progress.recorded_fields == ["sets", "reps", "load", "effort"]
      assert completion.progress.missing_fields == []
      assert completion.progress.label == "4 of 4 adaptive fields recorded"
    end

    test "reports missing fields without completing" do
      track = track()

      assert {:ok, completion, []} =
               Adaptive.completion(%Evaluation{
                 track: track,
                 date: ~D[2026-06-22],
                 journal_events: [
                   event(%{track_id: track.id, payload: %{"sets" => 3, "reps" => 10}})
                 ]
               })

      assert completion.status == :incomplete
      assert completion.progress.recorded_fields == ["sets", "reps"]
      assert completion.progress.missing_fields == ["load", "effort"]
      assert completion.progress.completed_event_ids == ["event-1"]
    end
  end

  defp track do
    %{
      id: "track-1",
      plan_id: "plan-1",
      event_type_id: "event-type-1",
      key: "practice_item",
      name: "Practice item",
      target: %{
        "type" => "adaptive",
        "fields" => ["sets", "reps", "load"],
        "effort" => "effort"
      },
      completion_policy: %{},
      missed_policy: %{}
    }
  end

  defp event(attrs) do
    Map.merge(
      %{
        id: "event-1",
        track_id: "track-1",
        status: :active,
        effective_at: ~U[2026-06-22 20:00:00Z],
        payload: %{}
      },
      attrs
    )
  end
end
