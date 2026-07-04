defmodule Improve.Planning.ProgressionPosition do
  @moduledoc """
  Evaluator graph capability provider for responsive progression position.

  Computes each responsive-progression track's current step position from
  journal history. The result is a map from track_id to position metadata,
  which downstream evaluators can use to make decisions (e.g. hold/advance
  proposals, deload suggestions).

  Descriptor:
    %{
      evaluator: :progression_position,
      kind: :derived_metric,
      provides: [:progression_positions],
      requires: [:date, :tracks, :journal_events, :timezone]
    }
  """

  alias Improve.Planning.LocalDate

  def descriptor do
    %{
      evaluator: :progression_position,
      kind: :derived_metric,
      provides: [:progression_positions],
      requires: [:date, :tracks, :journal_events, :timezone]
    }
  end

  def evaluate(%{date: date, tracks: tracks, journal_events: journal_events, timezone: timezone}) do
    positions =
      tracks
      |> Enum.filter(&responsive_progression?/1)
      |> Map.new(fn track ->
        {track.id, compute_position_data(track, journal_events, date, timezone)}
      end)

    {:ok, %{progression_positions: positions}, []}
  end

  defp responsive_progression?(%{target: target}) when is_map(target) do
    type = Map.get(target, "type") || Map.get(target, :type)
    has_steps = Map.has_key?(target, "steps") or Map.has_key?(target, :steps)
    type == "responsive_progression" or (has_steps and type != "progression")
  end

  defp responsive_progression?(_), do: false

  defp compute_position_data(track, journal_events, date, timezone) do
    target = track.target
    steps = Map.get(target, "steps") || Map.get(target, :steps) || []
    deload_after = target_int(target, "deload_after", 3)
    max_position = max(length(steps) - 1, 0)

    attempts = past_attempts(track, journal_events, date, timezone)

    {position, consecutive_failures} =
      Enum.reduce(attempts, {0, 0}, fn attempt, {pos, consecutive_fails} ->
        step = Enum.at(steps, pos) || %{}
        step_target = decimal(Map.get(step, "quantity"))

        if attempt_passes?(attempt, step_target) do
          {min(pos + 1, max_position), 0}
        else
          new_fails = consecutive_fails + 1

          if new_fails >= deload_after and pos > 0 do
            {pos - 1, 0}
          else
            {pos, new_fails}
          end
        end
      end)

    current_step = Enum.at(steps, position) || %{}

    %{
      position: position,
      total_steps: length(steps),
      consecutive_failures: consecutive_failures,
      current_step_target: Map.get(current_step, "quantity"),
      deload_after: deload_after,
      at_final_step: position == max_position and max_position > 0,
      attempts_count: length(attempts)
    }
  end

  defp past_attempts(track, journal_events, today, timezone) do
    journal_events
    |> Enum.filter(fn event ->
      event_value(event, :track_id) == track.id and
        event_value(event, :status) == :active and
        Date.compare(LocalDate.to_date(event_value(event, :effective_at), timezone), today) == :lt
    end)
    |> Enum.sort_by(&event_value(&1, :effective_at))
    |> Enum.group_by(&LocalDate.to_date(event_value(&1, :effective_at), timezone))
    |> Enum.sort_by(fn {date, _} -> date end)
    |> Enum.map(fn {_date, events} ->
      total =
        events
        |> Enum.map(&quantity_from_event(track, &1))
        |> Enum.reject(&is_nil/1)
        |> Enum.reduce(Decimal.new(0), &Decimal.add(&2, &1))

      %{total: total}
    end)
  end

  defp attempt_passes?(%{total: total}, nil), do: Decimal.compare(total, Decimal.new(0)) == :gt
  defp attempt_passes?(%{total: total}, target), do: Decimal.compare(total, target) != :lt

  defp quantity_from_event(track, event) do
    quantity = event_value(event, :quantity)
    decimal(quantity || payload_quantity(event, track.target))
  end

  defp payload_quantity(event, target) do
    path = Map.get(target, "quantity_path") || Map.get(target, :quantity_path)

    if path do
      event
      |> event_value(:payload)
      |> Improve.Planning.PathReader.value(path)
    end
  end

  defp target_int(target, key, default) do
    val = Map.get(target, key) || Map.get(target, String.to_existing_atom(key))

    case val do
      nil -> default
      v when is_integer(v) -> v
      v when is_binary(v) -> String.to_integer(v)
      _ -> default
    end
  rescue
    _ -> default
  end

  defp decimal(nil), do: nil
  defp decimal(%Decimal{} = value), do: value
  defp decimal(value) when is_integer(value), do: Decimal.new(value)
  defp decimal(value) when is_float(value), do: Decimal.from_float(value)

  defp decimal(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, ""} -> decimal
      _other -> nil
    end
  end

  defp decimal(_value), do: nil

  defp event_value(event, key), do: Map.get(event, key) || Map.get(event, to_string(key))
end
