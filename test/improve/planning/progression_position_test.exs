defmodule Improve.Planning.ProgressionPositionTest do
  use ExUnit.Case, async: true

  alias Improve.Planning.ProgressionPosition

  describe "descriptor/0" do
    test "provides progression_positions" do
      d = ProgressionPosition.descriptor()
      assert d.evaluator == :progression_position
      assert d.kind == :derived_metric
      assert :progression_positions in d.provides
      assert :tracks in d.requires
    end
  end

  describe "evaluate/1" do
    test "returns empty map when no responsive progression tracks" do
      input = %{
        date: ~D[2026-07-04],
        tracks: [fixed_track()],
        journal_events: [],
        timezone: "Etc/UTC"
      }

      assert {:ok, %{progression_positions: positions}, []} =
               ProgressionPosition.evaluate(input)

      assert positions == %{}
    end

    test "computes position for responsive progression track" do
      events = [
        event(%{id: "e1", effective_at: ~U[2026-07-01 10:00:00Z], quantity: 10}),
        event(%{id: "e2", effective_at: ~U[2026-07-02 10:00:00Z], quantity: 12})
      ]

      input = %{
        date: ~D[2026-07-04],
        tracks: [responsive_track()],
        journal_events: events,
        timezone: "Etc/UTC"
      }

      assert {:ok, %{progression_positions: positions}, []} =
               ProgressionPosition.evaluate(input)

      assert %{"track-resp" => position_data} = positions
      assert position_data.position == 2
      assert position_data.total_steps == 4
      assert position_data.consecutive_failures == 0
      assert position_data.attempts_count == 2
    end

    test "tracks consecutive failures" do
      events = [
        event(%{id: "e1", effective_at: ~U[2026-07-01 10:00:00Z], quantity: 10}),
        # Day 2: fails (needs 12, got 5)
        event(%{id: "e2", effective_at: ~U[2026-07-02 10:00:00Z], quantity: 5}),
        # Day 3: fails again (still at step 1, needs 12, got 4)
        event(%{id: "e3", effective_at: ~U[2026-07-03 10:00:00Z], quantity: 4})
      ]

      input = %{
        date: ~D[2026-07-04],
        tracks: [responsive_track()],
        journal_events: events,
        timezone: "Etc/UTC"
      }

      assert {:ok, %{progression_positions: positions}, []} =
               ProgressionPosition.evaluate(input)

      assert %{"track-resp" => position_data} = positions
      assert position_data.position == 1
      assert position_data.consecutive_failures == 2
    end

    test "deloads after configured consecutive failures" do
      events = [
        event(%{id: "e1", effective_at: ~U[2026-07-01 10:00:00Z], quantity: 10}),
        event(%{id: "e2", effective_at: ~U[2026-07-02 10:00:00Z], quantity: 12}),
        # Now at position 2 (target 14). Three failures:
        event(%{id: "e3", effective_at: ~U[2026-07-03 10:00:00Z], quantity: 1}),
        event(%{id: "e4", effective_at: ~U[2026-07-04 10:00:00Z], quantity: 1}),
        event(%{id: "e5", effective_at: ~U[2026-07-05 10:00:00Z], quantity: 1})
      ]

      input = %{
        date: ~D[2026-07-06],
        tracks: [responsive_track(%{target: responsive_target(3)})],
        journal_events: events,
        timezone: "Etc/UTC"
      }

      assert {:ok, %{progression_positions: positions}, []} =
               ProgressionPosition.evaluate(input)

      assert %{"track-resp" => position_data} = positions
      # Was at 2, deloaded back to 1 after 3 consecutive failures
      assert position_data.position == 1
    end

    test "works in evaluator graph" do
      alias Improve.Planning.EvaluatorGraph

      descriptors = [ProgressionPosition.descriptor()]
      evaluators = %{progression_position: &ProgressionPosition.evaluate/1}

      host_input = %{
        date: ~D[2026-07-04],
        tracks: [responsive_track()],
        journal_events: [
          event(%{id: "e1", effective_at: ~U[2026-07-01 10:00:00Z], quantity: 10})
        ],
        timezone: "Etc/UTC"
      }

      assert {:ok, result} = EvaluatorGraph.run(descriptors, host_input, evaluators)
      assert :progression_position in result.order
      assert %{"track-resp" => %{position: 1}} = result.outputs.progression_positions
    end
  end

  # --- helpers ---

  defp fixed_track do
    %{
      id: "track-fixed",
      plan_id: "plan-1",
      key: "stretching",
      target: %{"type" => "fixed", "quantity" => 1, "unit" => "session"}
    }
  end

  defp responsive_track(attrs \\ %{}) do
    Map.merge(
      %{
        id: "track-resp",
        plan_id: "plan-1",
        key: "long_run",
        target: responsive_target(3)
      },
      attrs
    )
  end

  defp responsive_target(deload_after) do
    %{
      "type" => "responsive_progression",
      "steps" => [
        %{"quantity" => 10},
        %{"quantity" => 12},
        %{"quantity" => 14},
        %{"quantity" => 16}
      ],
      "unit" => "km",
      "deload_after" => deload_after
    }
  end

  defp event(attrs) do
    Map.merge(
      %{
        id: "event-1",
        track_id: "track-resp",
        status: :active,
        effective_at: ~U[2026-07-04 10:00:00Z],
        quantity: nil,
        unit: "km",
        payload: %{}
      },
      attrs
    )
  end
end
