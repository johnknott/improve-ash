defmodule Improve.Bundles.StrengthTest do
  use ExUnit.Case, async: true

  alias Improve.Bundles.Strength.Fatigue
  alias Improve.Bundles.Strength.Adaptation
  alias Improve.Planning.BundleRegistry
  alias Improve.Planning.EvaluatorGraph
  alias Improve.Planning.ProgressionPosition

  describe "bundle registration" do
    test "strength bundle is known" do
      assert "strength" in BundleRegistry.known_keys()
    end

    test "returns descriptors" do
      {descriptors, []} = BundleRegistry.descriptors_for(["strength"])
      evaluator_names = Enum.map(descriptors, & &1.evaluator)
      assert :strength_fatigue in evaluator_names
      assert :strength_adaptation in evaluator_names
    end

    test "returns evaluator functions" do
      evaluators = BundleRegistry.evaluators_for(["strength"])
      assert Map.has_key?(evaluators, :strength_fatigue)
      assert Map.has_key?(evaluators, :strength_adaptation)
    end
  end

  describe "Fatigue evaluator" do
    test "returns low fatigue with no recent sessions" do
      input = %{
        date: ~D[2026-07-04],
        tracks: [strength_track()],
        journal_events: [],
        timezone: "Etc/UTC"
      }

      assert {:ok, %{strength_fatigue: fatigue}, []} = Fatigue.evaluate(input)
      assert fatigue.score == 0.0
      assert fatigue.session_count == 0
      assert fatigue.high == false
    end

    test "accumulates fatigue from recent sessions" do
      events =
        Enum.map(1..4, fn i ->
          %{
            id: "e#{i}",
            track_id: "track-bench",
            status: :active,
            effective_at: DateTime.new!(Date.add(~D[2026-07-04], -i), ~T[10:00:00]),
            quantity: 100,
            payload: %{}
          }
        end)

      input = %{
        date: ~D[2026-07-04],
        tracks: [strength_track()],
        journal_events: events,
        timezone: "Etc/UTC"
      }

      assert {:ok, %{strength_fatigue: fatigue}, []} = Fatigue.evaluate(input)
      assert fatigue.session_count == 4
      assert fatigue.score == 4 / 5
      assert fatigue.high == true
    end
  end

  describe "Adaptation evaluator" do
    test "no proposals when position is progressing normally" do
      input = %{
        date: ~D[2026-07-04],
        tracks: [strength_track()],
        journal_events: [],
        projected_work: [],
        strength_fatigue: %{score: 0.2, session_count: 1, high: false},
        progression_positions: %{
          "track-bench" => %{
            position: 2,
            total_steps: 5,
            consecutive_failures: 0,
            current_step_target: 70,
            deload_after: 3,
            at_final_step: false,
            attempts_count: 4
          }
        }
      }

      assert {:ok, %{strength_adaptation: adaptation}, []} = Adaptation.evaluate(input)
      assert adaptation.proposals == []
    end

    test "proposes deload when fatigued with consecutive failures" do
      input = %{
        date: ~D[2026-07-04],
        tracks: [strength_track()],
        journal_events: [],
        projected_work: [],
        strength_fatigue: %{score: 0.9, session_count: 5, high: true},
        progression_positions: %{
          "track-bench" => %{
            position: 3,
            total_steps: 5,
            consecutive_failures: 2,
            current_step_target: 80,
            deload_after: 3,
            at_final_step: false,
            attempts_count: 8
          }
        }
      }

      assert {:ok, %{strength_adaptation: adaptation}, []} = Adaptation.evaluate(input)
      assert [proposal] = adaptation.proposals
      assert proposal.kind == "strength_deload"
      assert proposal.proposed_edit.action == "rebase_progression"
      assert proposal.proposed_edit.track_id == "track-bench"
    end

    test "proposes goal adjustment when stalled" do
      input = %{
        date: ~D[2026-07-04],
        tracks: [strength_track()],
        journal_events: [],
        projected_work: [],
        strength_fatigue: %{score: 0.3, session_count: 2, high: false},
        progression_positions: %{
          "track-bench" => %{
            position: 2,
            total_steps: 5,
            consecutive_failures: 3,
            current_step_target: 70,
            deload_after: 3,
            at_final_step: false,
            attempts_count: 8
          }
        }
      }

      assert {:ok, %{strength_adaptation: adaptation}, []} = Adaptation.evaluate(input)
      assert [proposal] = adaptation.proposals
      assert proposal.kind == "strength_goal_adjustment"
      assert proposal.proposed_edit.action == "adjust_goal"
      assert proposal.evidence.proposed_target == 56
    end
  end

  describe "full evaluator graph integration" do
    test "runs strength pipeline with progression_position" do
      {descriptors, []} = BundleRegistry.descriptors_for(["strength"])
      evaluators = BundleRegistry.evaluators_for(["strength"])

      all_descriptors = [ProgressionPosition.descriptor() | descriptors]
      all_evaluators = Map.put(evaluators, :progression_position, &ProgressionPosition.evaluate/1)

      events = [
        %{
          id: "e1",
          track_id: "track-bench",
          status: :active,
          effective_at: ~U[2026-07-01 10:00:00Z],
          quantity: 60,
          payload: %{}
        },
        %{
          id: "e2",
          track_id: "track-bench",
          status: :active,
          effective_at: ~U[2026-07-02 10:00:00Z],
          quantity: 70,
          payload: %{}
        }
      ]

      host_input = %{
        date: ~D[2026-07-04],
        tracks: [strength_track()],
        journal_events: events,
        projected_work: [],
        timezone: "Etc/UTC"
      }

      assert {:ok, result} = EvaluatorGraph.run(all_descriptors, host_input, all_evaluators)

      assert :progression_position in result.order
      assert :strength_fatigue in result.order
      assert :strength_adaptation in result.order

      assert Map.has_key?(result.outputs, :progression_positions)
      assert Map.has_key?(result.outputs, :strength_fatigue)
      assert Map.has_key?(result.outputs, :strength_adaptation)
    end
  end

  # --- helpers ---

  defp strength_track do
    %{
      id: "track-bench",
      plan_id: "plan-1",
      key: "bench_press",
      name: "Bench Press",
      target: %{
        "type" => "responsive_progression",
        "steps" => [
          %{"quantity" => 60},
          %{"quantity" => 70},
          %{"quantity" => 80},
          %{"quantity" => 90},
          %{"quantity" => 100}
        ],
        "unit" => "kg",
        "deload_after" => 3
      },
      completion_policy: %{},
      missed_policy: %{}
    }
  end
end
