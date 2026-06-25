defmodule Improve.Planning.Targets.FixedTest do
  use ExUnit.Case, async: true

  alias Improve.Planning.Targets
  alias Improve.Planning.Targets.Evaluation
  alias Improve.Planning.Targets.Fixed

  describe "completion/1" do
    test "completes a fixed target from active same-day linked journal events" do
      track = track(%{target: %{"type" => "fixed", "quantity" => 20, "unit" => "pages"}})

      linked = event(%{id: "event-1", track_id: track.id, effective_at: ~U[2026-06-22 20:00:00Z]})

      other_day =
        event(%{id: "event-2", track_id: track.id, effective_at: ~U[2026-06-23 20:00:00Z]})

      inactive =
        event(%{
          id: "event-3",
          track_id: track.id,
          status: :voided,
          effective_at: ~U[2026-06-22 20:00:00Z]
        })

      other_track =
        event(%{id: "event-4", track_id: "other-track", effective_at: ~U[2026-06-22 20:00:00Z]})

      assert {:ok, completion, []} =
               Fixed.completion(%Evaluation{
                 track: track,
                 date: ~D[2026-06-22],
                 as_of_date: ~D[2026-06-22],
                 journal_events: [other_day, linked, inactive, other_track]
               })

      assert completion.status == :completed
      assert completion.completed_events == [linked]
      assert completion.progress.completed_event_count == 1
      assert completion.progress.completed_event_ids == ["event-1"]
    end

    test "returns incomplete progress when no linked journal event exists for the date" do
      track = track(%{target: %{"type" => "fixed", "quantity" => 20, "unit" => "pages"}})

      assert {:ok, completion, []} =
               Fixed.completion(%Evaluation{
                 track: track,
                 date: ~D[2026-06-22],
                 as_of_date: ~D[2026-06-23],
                 journal_events: []
               })

      assert completion.status == :incomplete
      assert completion.completed_events == []
      assert completion.progress.completed_event_count == 0
      assert completion.progress.completed_event_ids == []
    end
  end

  describe "Targets.completion/2" do
    test "keeps the legacy fixed-like target fallback behind the fixed evaluator" do
      track = track(%{target: %{"quantity" => 20, "unit" => "pages"}})
      linked = event(%{id: "event-1", track_id: track.id, effective_at: ~U[2026-06-22 20:00:00Z]})

      assert {:ok, completion, []} =
               Targets.completion(track, %{
                 date: ~D[2026-06-22],
                 as_of_date: ~D[2026-06-22],
                 journal_events: [linked]
               })

      assert completion.status == :completed
      assert completion.completed_events == [linked]
    end
  end

  defp track(attrs) do
    Map.merge(
      %{
        id: "track-1",
        plan_id: "plan-1",
        event_type_id: "event-type-1",
        key: "read_pages",
        name: "Read pages",
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
        effective_at: ~U[2026-06-22 20:00:00Z]
      },
      attrs
    )
  end
end
