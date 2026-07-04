defmodule Improve.App.DriftRule do
  @moduledoc """
  Detects persistent drift in derived adjustments and emits re-baseline proposals.

  When N consecutive projections show the same-direction adjustment on a track,
  the drift rule proposes a durable re-baseline: changing the authored target to
  match what the evaluator has been deriving. This converts noise-level adaptation
  into explicit, human-approved plan edits.

  The rule is intentionally conservative:
  - Only fires after `threshold` consecutive same-direction adjustments (default 5)
  - Only fires when the existing authored target differs from the derived effective value
  - Won't propose if the same divergence_key was recently dismissed
  """

  @default_threshold 5

  @type adjustment_record :: %{
          required(:track_id) => String.t(),
          required(:date) => Date.t(),
          required(:direction) => :down | :up,
          required(:authored_value) => term(),
          required(:effective_value) => term(),
          required(:source) => String.t(),
          required(:reason) => String.t()
        }

  @type drift_proposal :: %{
          required(:kind) => String.t(),
          required(:divergence_key) => String.t(),
          required(:source) => String.t(),
          required(:text) => String.t(),
          required(:proposed_edit) => map(),
          required(:evidence) => map(),
          required(:affected_fields) => [String.t()]
        }

  @doc """
  Evaluates adjustment history for drift and returns proposals for tracks
  that have been consistently adjusted in one direction.

  `adjustment_history` is a list of adjustment records ordered chronologically.
  Each record captures one day's derived adjustment for one track.
  """
  @spec detect([adjustment_record()], keyword()) :: [drift_proposal()]
  def detect(adjustment_history, opts \\ []) do
    threshold = Keyword.get(opts, :threshold, @default_threshold)

    adjustment_history
    |> group_by_track()
    |> Enum.flat_map(fn {track_id, records} ->
      detect_for_track(track_id, records, threshold)
    end)
  end

  @doc """
  Builds adjustment records from a list of projections (multi-day history).

  Each projection must include `:evaluator_output` with `:derived_target_adjustments`.
  """
  @spec records_from_projections([map()]) :: [adjustment_record()]
  def records_from_projections(projections) when is_list(projections) do
    Enum.flat_map(projections, &records_from_projection/1)
  end

  defp records_from_projection(projection) do
    date = Map.get(projection, :date)
    adjustments = get_derived_adjustments(projection)

    Enum.map(adjustments, fn {track_id, adjustment} ->
      authored = Map.get(adjustment, :authored) || Map.get(adjustment, "authored")
      effective = Map.get(adjustment, :effective) || Map.get(adjustment, "effective")
      source = to_string(Map.get(adjustment, :source) || Map.get(adjustment, "source") || "unknown")
      reason = Map.get(adjustment, :reason) || Map.get(adjustment, "reason") || ""

      %{
        track_id: to_string(track_id),
        date: date,
        direction: direction(authored, effective),
        authored_value: authored,
        effective_value: effective,
        source: source,
        reason: reason
      }
    end)
  end

  defp get_derived_adjustments(projection) do
    evaluator_output = Map.get(projection, :evaluator_output, %{}) || %{}
    Map.get(evaluator_output, :derived_target_adjustments, %{}) || %{}
  end

  defp group_by_track(records) do
    Enum.group_by(records, & &1.track_id)
  end

  defp detect_for_track(track_id, records, threshold) do
    sorted = Enum.sort_by(records, & &1.date)
    trailing = Enum.take(sorted, -threshold)

    if length(trailing) >= threshold and all_same_direction?(trailing) do
      direction = hd(trailing).direction
      latest = List.last(trailing)

      [
        %{
          kind: "drift_rebaseline",
          divergence_key: "drift_rebaseline:#{track_id}",
          source: "drift_rule",
          text: drift_text(track_id, direction, latest, threshold),
          proposed_edit: %{
            action: "adjust_goal",
            track_id: track_id,
            target_changes: target_changes(latest)
          },
          evidence: %{
            track_id: track_id,
            direction: direction,
            consecutive_adjustments: length(trailing),
            from_date: hd(trailing).date,
            to_date: latest.date,
            latest_authored: latest.authored_value,
            latest_effective: latest.effective_value,
            source: latest.source,
            reason: latest.reason
          },
          affected_fields: ["target"]
        }
      ]
    else
      []
    end
  end

  defp all_same_direction?([]), do: false

  defp all_same_direction?(records) do
    direction = hd(records).direction
    direction != nil and Enum.all?(records, &(&1.direction == direction))
  end

  defp direction(nil, _effective), do: nil
  defp direction(_authored, nil), do: nil

  defp direction(authored, effective) when is_number(authored) and is_number(effective) do
    cond do
      effective < authored -> :down
      effective > authored -> :up
      true -> nil
    end
  end

  defp direction(authored, effective) when is_binary(authored) and is_binary(effective) do
    with {a, _} <- Float.parse(authored),
         {e, _} <- Float.parse(effective) do
      direction(a, e)
    else
      _ -> nil
    end
  end

  defp direction(authored, effective) do
    direction(to_number(authored), to_number(effective))
  end

  defp to_number(n) when is_number(n), do: n

  defp to_number(s) when is_binary(s) do
    case Float.parse(s) do
      {f, _} -> f
      :error -> nil
    end
  end

  defp to_number(%Decimal{} = d), do: Decimal.to_float(d)
  defp to_number(_), do: nil

  defp drift_text(track_id, :down, latest, count) do
    "Target has been reduced for #{count} consecutive days on track #{track_id}. " <>
      "Consider rebasing to #{inspect(latest.effective_value)} " <>
      "(was #{inspect(latest.authored_value)}). Reason: #{latest.reason}"
  end

  defp drift_text(track_id, :up, latest, count) do
    "Target has been raised for #{count} consecutive days on track #{track_id}. " <>
      "Consider rebasing to #{inspect(latest.effective_value)} " <>
      "(was #{inspect(latest.authored_value)}). Reason: #{latest.reason}"
  end

  defp target_changes(latest) do
    effective = latest.effective_value

    case effective do
      %{} = map -> map
      value -> %{"quantity" => value}
    end
  end
end
