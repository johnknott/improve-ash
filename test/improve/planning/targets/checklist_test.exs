defmodule Improve.Planning.Targets.ChecklistTest do
  use ExUnit.Case, async: true

  alias Improve.Planning.Targets.Checklist
  alias Improve.Planning.Targets.Evaluation

  describe "completion/1" do
    test "completes when same-day linked events cover all checklist items" do
      track = track(%{target: %{"type" => "checklist", "items" => ["Tidy room", "Brush teeth"]}})

      first =
        event(%{
          id: "event-1",
          track_id: track.id,
          payload: %{"completed_items" => ["Tidy room"]}
        })

      second =
        event(%{
          id: "event-2",
          track_id: track.id,
          payload: %{"completed_items" => ["Brush teeth"]}
        })

      assert {:ok, completion, []} =
               Checklist.completion(%Evaluation{
                 track: track,
                 date: ~D[2026-06-22],
                 journal_events: [first, second]
               })

      assert completion.status == :completed
      assert completion.completed_events == [first, second]
      assert completion.progress.completed_count == 2
      assert completion.progress.required_count == 2
      assert completion.progress.completed_items == ["Brush teeth", "Tidy room"]
      assert completion.progress.label == "2 of 2 complete"
    end

    test "supports key-label checklist_items and reports partial progress" do
      track =
        track(%{
          target: %{
            "checklist_items" => [
              %{"key" => "tidy_room", "label" => "Tidy room"},
              %{"key" => "brush_teeth", "label" => "Brush teeth"}
            ]
          }
        })

      assert {:ok, completion, []} =
               Checklist.completion(%Evaluation{
                 track: track,
                 date: ~D[2026-06-22],
                 journal_events: [
                   event(%{
                     track_id: track.id,
                     payload: %{"completed_items" => [%{"key" => "tidy_room"}]}
                   })
                 ]
               })

      assert completion.status == :incomplete
      assert completion.progress.completed_count == 1
      assert completion.progress.required_count == 2
      assert completion.progress.completed_items == ["tidy_room"]
      assert completion.progress.required_items == ["tidy_room", "brush_teeth"]
    end

    test "supports the authored checked_items payload field" do
      track = track(%{target: %{"type" => "checklist", "items" => ["Tidy room"]}})

      assert {:ok, completion, []} =
               Checklist.completion(%Evaluation{
                 track: track,
                 date: ~D[2026-06-22],
                 journal_events: [
                   event(%{
                     track_id: track.id,
                     payload: %{"checked_items" => ["Tidy room"]}
                   })
                 ]
               })

      assert completion.status == :completed
      assert completion.progress.completed_items == ["Tidy room"]
    end
  end

  defp track(attrs) do
    Map.merge(
      %{
        id: "track-1",
        plan_id: "plan-1",
        event_type_id: "event-type-1",
        key: "evening_reset",
        name: "Evening reset",
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
        payload: %{}
      },
      attrs
    )
  end
end
