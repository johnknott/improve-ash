defmodule Improve.Planning.Targets.ResponsiveProgression do
  @moduledoc """
  Performance-gated progression target evaluator.

  Instead of advancing by calendar date (scheduled progression), this evaluator
  advances when the user succeeds. Position holds on failure and deloads after
  consecutive failures.

  Target map shape:
    %{
      "type" => "responsive_progression",
      "steps" => [%{"quantity" => 10}, %{"quantity" => 12}, ...],
      "unit" => "km",
      "advance_on" => "success",        # advance when step target is met
      "hold_on" => "failure",            # hold position when step is missed
      "deload_after" => 3               # deload (step back) after N consecutive failures
    }
  """

  @behaviour Improve.Planning.Targets.Evaluator

  alias Improve.Planning.LocalDate

  def target_type, do: "responsive_progression"

  def diagnostics(%{track: track}) do
    steps = steps(track.target)

    if steps == [] do
      [
        %{
          code: :empty_progression_steps,
          severity: :warning,
          message: "Responsive progression has no steps defined.",
          details: %{track_id: track.id, track_key: track.key}
        }
      ]
    else
      []
    end
  end

  def completion(%{track: track, date: date, journal_events: journal_events} = evaluation) do
    timezone = Map.get(evaluation, :timezone) || LocalDate.default_timezone()
    target = track.target
    steps = steps(target)
    deload_after = target_int(target, "deload_after", 3)

    position = compute_position(track, steps, journal_events, date, timezone, deload_after)
    current_step = Enum.at(steps, position) || List.last(steps) || %{}
    expected = decimal(Map.get(current_step, "quantity"))

    today_entries =
      journal_events
      |> Enum.filter(&completed_event_for?(track, date, timezone, &1))
      |> Enum.map(&quantity_entry(track, &1))
      |> Enum.reject(&is_nil(&1.quantity))

    total = Enum.reduce(today_entries, Decimal.new(0), &Decimal.add(&2, &1.quantity))

    status =
      if not is_nil(expected) and Decimal.compare(total, expected) != :lt do
        :completed
      else
        :incomplete
      end

    {:ok,
     %{
       status: status,
       completed_events: Enum.map(today_entries, & &1.event),
       progress:
         progress(today_entries, total, expected, track, position, steps, deload_after)
     }, []}
  end

  defp compute_position(track, steps, journal_events, date, timezone, deload_after) do
    max_position = max(length(steps) - 1, 0)

    attempts = past_attempts(track, journal_events, date, timezone, steps)

    {position, _consecutive_failures} =
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

    position
  end

  defp past_attempts(track, journal_events, today, timezone, _steps) do
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

  defp completed_event_for?(track, date, timezone, event) do
    event_value(event, :track_id) == track.id and event_value(event, :status) == :active and
      Date.compare(LocalDate.to_date(event_value(event, :effective_at), timezone), date) == :eq
  end

  defp quantity_entry(track, event) do
    %{
      event: event,
      event_id: event_value(event, :id),
      quantity: quantity_from_event(track, event)
    }
  end

  defp quantity_from_event(track, event) do
    quantity =
      event_value(event, :quantity) ||
        payload_value(event, target_value(track.target, "quantity_path"))

    decimal(quantity)
  end

  defp progress(entries, total, expected, track, position, steps, deload_after) do
    unit = target_value(track.target, "unit")

    %{
      completed_event_count: length(entries),
      completed_event_ids: Enum.map(entries, & &1.event_id),
      total_quantity: display_number(total),
      expected_quantity: display_number(expected),
      unit: unit,
      position: position,
      total_steps: length(steps),
      deload_after: deload_after,
      mode: "responsive",
      label: responsive_label(total, expected, unit, position, steps)
    }
  end

  defp responsive_label(total, expected, unit, position, steps) do
    step_label = "step #{position + 1}/#{length(steps)}"

    "#{display_number(total)} of #{display_number(expected)} #{unit} (#{step_label})"
  end

  defp steps(target) do
    Map.get(target, "steps") || Map.get(target, :steps) || []
  end

  defp target_int(target, key, default) do
    case target_value(target, key) do
      nil -> default
      v when is_integer(v) -> v
      v when is_binary(v) -> String.to_integer(v)
      _ -> default
    end
  rescue
    _ -> default
  end

  defp payload_value(event, path) when is_binary(path) do
    event
    |> event_value(:payload)
    |> Improve.Planning.PathReader.value(path)
  end

  defp payload_value(_event, _path), do: nil

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

  defp display_number(nil), do: nil

  defp display_number(%Decimal{} = value) do
    value |> Decimal.normalize() |> Decimal.to_string(:normal)
  end

  defp target_value(nil, _key), do: nil
  defp target_value(target, key), do: Map.get(target, key) || Map.get(target, existing_atom(key))

  defp event_value(event, key), do: Map.get(event, key) || Map.get(event, to_string(key))

  defp existing_atom(key) when is_binary(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end
end
