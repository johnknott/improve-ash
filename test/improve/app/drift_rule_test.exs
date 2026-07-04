defmodule Improve.App.DriftRuleTest do
  use ExUnit.Case, async: true

  alias Improve.App.DriftRule

  describe "detect/2" do
    test "returns empty when no history" do
      assert DriftRule.detect([]) == []
    end

    test "returns empty when fewer than threshold consecutive same-direction" do
      records =
        Enum.map(1..4, fn i ->
          %{
            track_id: "track-1",
            date: Date.add(~D[2026-07-01], i - 1),
            direction: :down,
            authored_value: 25,
            effective_value: 20,
            source: "marathon_target_adjustment",
            reason: "low recent load"
          }
        end)

      assert DriftRule.detect(records, threshold: 5) == []
    end

    test "emits re-baseline proposal when threshold met" do
      records =
        Enum.map(1..5, fn i ->
          %{
            track_id: "track-1",
            date: Date.add(~D[2026-07-01], i - 1),
            direction: :down,
            authored_value: 25,
            effective_value: 20,
            source: "marathon_target_adjustment",
            reason: "low recent load"
          }
        end)

      assert [proposal] = DriftRule.detect(records, threshold: 5)
      assert proposal.kind == "drift_rebaseline"
      assert proposal.divergence_key == "drift_rebaseline:track-1"
      assert proposal.proposed_edit.action == "adjust_goal"
      assert proposal.proposed_edit.track_id == "track-1"
      assert proposal.evidence.direction == :down
      assert proposal.evidence.consecutive_adjustments == 5
    end

    test "does not fire when directions are mixed" do
      records = [
        %{
          track_id: "t1",
          date: ~D[2026-07-01],
          direction: :down,
          authored_value: 25,
          effective_value: 20,
          source: "s",
          reason: "r"
        },
        %{
          track_id: "t1",
          date: ~D[2026-07-02],
          direction: :down,
          authored_value: 25,
          effective_value: 20,
          source: "s",
          reason: "r"
        },
        %{
          track_id: "t1",
          date: ~D[2026-07-03],
          direction: :up,
          authored_value: 20,
          effective_value: 25,
          source: "s",
          reason: "r"
        },
        %{
          track_id: "t1",
          date: ~D[2026-07-04],
          direction: :down,
          authored_value: 25,
          effective_value: 20,
          source: "s",
          reason: "r"
        },
        %{
          track_id: "t1",
          date: ~D[2026-07-05],
          direction: :down,
          authored_value: 25,
          effective_value: 20,
          source: "s",
          reason: "r"
        }
      ]

      assert DriftRule.detect(records, threshold: 5) == []
    end

    test "handles multiple tracks independently" do
      records =
        Enum.flat_map(1..5, fn i ->
          [
            %{
              track_id: "t1",
              date: Date.add(~D[2026-07-01], i - 1),
              direction: :down,
              authored_value: 25,
              effective_value: 20,
              source: "s",
              reason: "r"
            },
            %{
              track_id: "t2",
              date: Date.add(~D[2026-07-01], i - 1),
              direction: :up,
              authored_value: 10,
              effective_value: 15,
              source: "s",
              reason: "r"
            }
          ]
        end)

      proposals = DriftRule.detect(records, threshold: 5)
      assert length(proposals) == 2

      keys = Enum.map(proposals, & &1.divergence_key)
      assert "drift_rebaseline:t1" in keys
      assert "drift_rebaseline:t2" in keys
    end
  end

  describe "records_from_projections/1" do
    test "extracts adjustment records from projection output" do
      projections = [
        %{
          date: ~D[2026-07-01],
          evaluator_output: %{
            derived_target_adjustments: %{
              "track-1" => %{
                authored: 25,
                effective: 20,
                source: :marathon_target_adjustment,
                reason: "low load"
              }
            }
          }
        },
        %{
          date: ~D[2026-07-02],
          evaluator_output: %{
            derived_target_adjustments: %{
              "track-1" => %{
                authored: 25,
                effective: 20,
                source: :marathon_target_adjustment,
                reason: "low load"
              }
            }
          }
        }
      ]

      records = DriftRule.records_from_projections(projections)
      assert length(records) == 2
      assert Enum.all?(records, &(&1.track_id == "track-1"))
      assert Enum.all?(records, &(&1.direction == :down))
    end

    test "returns empty for projections with no evaluator output" do
      projections = [
        %{date: ~D[2026-07-01], evaluator_output: nil},
        %{date: ~D[2026-07-02]}
      ]

      assert DriftRule.records_from_projections(projections) == []
    end
  end
end
