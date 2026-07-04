defmodule Improve.Bundles.Strength.Adaptation do
  @moduledoc """
  Strength adaptation evaluator.

  Consumes progression_positions and fatigue to decide:
  - If fatigue is high and position shows consecutive failures → propose deload
  - If position is stalled for too long → propose adjust_goal (lower step targets)

  Emits committed_proposals that flow through ProposalSync.
  """

  @stall_threshold 3
  @deload_step_reduction 0.8

  def evaluate(input) do
    tracks = Map.get(input, :tracks, [])
    positions = Map.get(input, :progression_positions, %{})
    fatigue = Map.get(input, :strength_fatigue, %{})
    projected_work = Map.get(input, :projected_work, [])

    proposals =
      tracks
      |> Enum.filter(&strength_track?/1)
      |> Enum.flat_map(fn track ->
        position_data = Map.get(positions, track.id, %{})
        evaluate_track(track, position_data, fatigue)
      end)

    adaptation = %{
      today: Enum.map(projected_work, &summarize_work/1),
      proposals: proposals,
      committed_proposals: proposals,
      fatigue: fatigue
    }

    {:ok, %{strength_adaptation: adaptation}, []}
  end

  defp evaluate_track(track, position_data, fatigue) do
    consecutive_failures = Map.get(position_data, :consecutive_failures, 0)
    high_fatigue = Map.get(fatigue, :high, false)

    cond do
      high_fatigue and consecutive_failures >= 2 ->
        [deload_proposal(track, position_data, fatigue)]

      consecutive_failures >= @stall_threshold ->
        [adjust_goal_proposal(track, position_data)]

      true ->
        []
    end
  end

  defp deload_proposal(track, position_data, fatigue) do
    %{
      kind: "strength_deload",
      divergence_key: "strength_deload:#{track.id}",
      source: "strength_adaptation",
      text:
        "High fatigue (score: #{Float.round(fatigue.score, 2)}) with #{position_data.consecutive_failures} consecutive failures. Consider a deload week.",
      proposed_edit: %{
        action: "rebase_progression",
        track_id: track.id,
        shift_weeks: -1
      },
      evidence: %{
        track_id: track.id,
        fatigue_score: fatigue.score,
        consecutive_failures: position_data.consecutive_failures,
        position: position_data.position
      },
      affected_fields: ["target"]
    }
  end

  defp adjust_goal_proposal(track, position_data) do
    current_target = Map.get(position_data, :current_step_target)
    reduced = if current_target, do: round(current_target * @deload_step_reduction), else: nil

    %{
      kind: "strength_goal_adjustment",
      divergence_key: "strength_goal_adjustment:#{track.id}",
      source: "strength_adaptation",
      text:
        "Stalled at step #{position_data.position + 1} for #{position_data.consecutive_failures} attempts. Consider reducing step target.",
      proposed_edit: %{
        action: "adjust_goal",
        track_id: track.id,
        target_changes: reduce_current_step(track, position_data, reduced)
      },
      evidence: %{
        track_id: track.id,
        consecutive_failures: position_data.consecutive_failures,
        position: position_data.position,
        current_target: current_target,
        proposed_target: reduced
      },
      affected_fields: ["target.steps"]
    }
  end

  defp reduce_current_step(track, position_data, reduced) when not is_nil(reduced) do
    target = Map.get(track, :target) || %{}
    steps = Map.get(target, "steps") || Map.get(target, :steps) || []
    pos = position_data.position

    updated_steps =
      List.update_at(steps, pos, fn step ->
        Map.put(step, "quantity", reduced)
      end)

    %{"steps" => updated_steps}
  end

  defp reduce_current_step(_track, _position_data, nil), do: %{}

  defp strength_track?(track) do
    target = Map.get(track, :target) || %{}
    type = Map.get(target, "type") || Map.get(target, :type) || ""
    key = Map.get(track, :key) || ""

    type == "responsive_progression" or
      String.contains?(key, "strength") or
      String.contains?(key, "lift")
  end

  defp summarize_work(work) do
    %{
      owner_key: Map.get(work, :owner_key),
      status: Map.get(work, :status),
      kind: Map.get(work, :kind)
    }
  end
end
