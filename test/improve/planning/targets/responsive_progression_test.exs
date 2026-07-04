defmodule Improve.Planning.Targets.ResponsiveProgressionTest do
  use ExUnit.Case, async: true

  alias Improve.Planning.Targets.Evaluation
  alias Improve.Planning.Targets.ResponsiveProgression

  describe "completion/1 - basic advancement" do
    test "starts at step 0 with no history" do
      assert {:ok, completion, []} =
               ResponsiveProgression.completion(%Evaluation{
                 track: track(),
                 date: ~D[2026-07-04],
                 journal_events: []
               })

      assert completion.status == :incomplete
      assert completion.progress.position == 0
      assert completion.progress.expected_quantity == "5"
      assert completion.progress.mode == "responsive"
    end

    test "advances to step 1 after completing step 0" do
      assert {:ok, completion, []} =
               ResponsiveProgression.completion(%Evaluation{
                 track: track(),
                 date: ~D[2026-07-05],
                 journal_events: [
                   event(%{effective_at: ~U[2026-07-04 10:00:00Z], quantity: 5})
                 ]
               })

      assert completion.status == :incomplete
      assert completion.progress.position == 1
      assert completion.progress.expected_quantity == "6"
    end

    test "advances through multiple steps" do
      events = [
        event(%{id: "e1", effective_at: ~U[2026-07-01 10:00:00Z], quantity: 5}),
        event(%{id: "e2", effective_at: ~U[2026-07-02 10:00:00Z], quantity: 6}),
        event(%{id: "e3", effective_at: ~U[2026-07-03 10:00:00Z], quantity: 7})
      ]

      assert {:ok, completion, []} =
               ResponsiveProgression.completion(%Evaluation{
                 track: track(),
                 date: ~D[2026-07-04],
                 journal_events: events
               })

      assert completion.progress.position == 3
      assert completion.progress.expected_quantity == "8"
    end

    test "completes when today's total meets current step target" do
      events = [
        event(%{id: "e1", effective_at: ~U[2026-07-03 10:00:00Z], quantity: 5}),
        event(%{id: "e2", effective_at: ~U[2026-07-04 10:00:00Z], quantity: 6})
      ]

      assert {:ok, completion, []} =
               ResponsiveProgression.completion(%Evaluation{
                 track: track(),
                 date: ~D[2026-07-04],
                 journal_events: events
               })

      assert completion.status == :completed
      assert completion.progress.total_quantity == "6"
    end
  end

  describe "completion/1 - hold on failure" do
    test "holds position when a day is missed" do
      events = [
        event(%{id: "e1", effective_at: ~U[2026-07-01 10:00:00Z], quantity: 5}),
        event(%{id: "e2", effective_at: ~U[2026-07-02 10:00:00Z], quantity: 2})
      ]

      assert {:ok, completion, []} =
               ResponsiveProgression.completion(%Evaluation{
                 track: track(),
                 date: ~D[2026-07-04],
                 journal_events: events
               })

      # Day 1 passed (5>=5) -> pos 1, Day 2 failed (2<6) -> hold at 1
      assert completion.progress.position == 1
      assert completion.progress.expected_quantity == "6"
    end
  end

  describe "completion/1 - deload after consecutive failures" do
    test "deloads (steps back) after N consecutive failures" do
      events = [
        event(%{id: "e1", effective_at: ~U[2026-07-01 10:00:00Z], quantity: 5}),
        event(%{id: "e2", effective_at: ~U[2026-07-02 10:00:00Z], quantity: 6}),
        # Now at position 2, target is 7. Three consecutive failures:
        event(%{id: "e3", effective_at: ~U[2026-07-03 10:00:00Z], quantity: 1}),
        event(%{id: "e4", effective_at: ~U[2026-07-04 10:00:00Z], quantity: 1}),
        event(%{id: "e5", effective_at: ~U[2026-07-05 10:00:00Z], quantity: 1})
      ]

      assert {:ok, completion, []} =
               ResponsiveProgression.completion(%Evaluation{
                 track: track(%{target: target_with_deload(2)}),
                 date: ~D[2026-07-06],
                 journal_events: events
               })

      # After 2 consecutive failures at position 2, deloads to position 1
      assert completion.progress.position == 1
      assert completion.progress.expected_quantity == "6"
    end
  end

  describe "completion/1 - stays at final step" do
    test "does not advance past last step" do
      steps = [%{"quantity" => 5}, %{"quantity" => 10}]

      events = [
        event(%{id: "e1", effective_at: ~U[2026-07-01 10:00:00Z], quantity: 5}),
        event(%{id: "e2", effective_at: ~U[2026-07-02 10:00:00Z], quantity: 10}),
        event(%{id: "e3", effective_at: ~U[2026-07-03 10:00:00Z], quantity: 10})
      ]

      assert {:ok, completion, []} =
               ResponsiveProgression.completion(%Evaluation{
                 track:
                   track(%{
                     target: %{
                       "type" => "responsive_progression",
                       "steps" => steps,
                       "unit" => "km"
                     }
                   }),
                 date: ~D[2026-07-04],
                 journal_events: events
               })

      assert completion.progress.position == 1
      assert completion.progress.total_steps == 2
    end
  end

  describe "diagnostics/1" do
    test "returns warning for empty steps" do
      track =
        track(%{target: %{"type" => "responsive_progression", "steps" => [], "unit" => "km"}})

      diagnostics = ResponsiveProgression.diagnostics(%{track: track})
      assert [%{code: :empty_progression_steps}] = diagnostics
    end

    test "returns no diagnostics with valid steps" do
      diagnostics = ResponsiveProgression.diagnostics(%{track: track()})
      assert diagnostics == []
    end
  end

  describe "progress label" do
    test "includes step position info" do
      assert {:ok, completion, []} =
               ResponsiveProgression.completion(%Evaluation{
                 track: track(),
                 date: ~D[2026-07-04],
                 journal_events: []
               })

      assert completion.progress.label =~ "step 1/5"
      assert completion.progress.label =~ "of 5"
    end
  end

  # --- helpers ---

  defp track(attrs \\ %{}) do
    Map.merge(
      %{
        id: "track-1",
        plan_id: "plan-1",
        event_type_id: "event-type-1",
        key: "long_run",
        name: "Long Run",
        target: %{
          "type" => "responsive_progression",
          "steps" => [
            %{"quantity" => 5},
            %{"quantity" => 6},
            %{"quantity" => 7},
            %{"quantity" => 8},
            %{"quantity" => 9}
          ],
          "unit" => "km",
          "deload_after" => 3
        },
        completion_policy: %{},
        missed_policy: %{}
      },
      attrs
    )
  end

  defp target_with_deload(deload_after) do
    %{
      "type" => "responsive_progression",
      "steps" => [
        %{"quantity" => 5},
        %{"quantity" => 6},
        %{"quantity" => 7},
        %{"quantity" => 8},
        %{"quantity" => 9}
      ],
      "unit" => "km",
      "deload_after" => deload_after
    }
  end

  defp event(attrs) do
    Map.merge(
      %{
        id: "event-1",
        track_id: "track-1",
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
