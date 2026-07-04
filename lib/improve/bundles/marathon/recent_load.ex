defmodule Improve.Bundles.Marathon.RecentLoad do
  @moduledoc """
  Derived metric evaluator for recent running load.

  The evaluator is hermetic: it receives bounded projection input, reads no
  database or clock, and returns a metric plus diagnostics.
  """

  @window_days 7

  @doc """
  Computes `recent_load_km` for active running events in the 7-day window ending
  on `as_of_date`.
  """
  def evaluate(input) when is_map(input) do
    as_of_date = Map.fetch!(input, :as_of_date)
    timezone = Map.get(input, :timezone) || Improve.Planning.LocalDate.default_timezone()
    window_start = Date.add(as_of_date, -(@window_days - 1))
    running_track_ids = running_track_ids(Map.get(input, :tracks, []))

    {total, event_ids, diagnostics} =
      input
      |> Map.get(:journal_events, [])
      |> Enum.reduce({0.0, [], []}, fn event, {total, event_ids, diagnostics} ->
        evaluate_event(event, running_track_ids, window_start, as_of_date, timezone, {
          total,
          event_ids,
          diagnostics
        })
      end)

    diagnostics =
      diagnostics ++
        empty_history_diagnostics(event_ids, %{
          window_days: @window_days,
          window_start: window_start,
          as_of: as_of_date
        })

    {:ok,
     %{
       recent_load_km: %{
         metric: :recent_load_km,
         value: normalize_number(total),
         unit: "km",
         window_days: @window_days,
         as_of: as_of_date,
         window_start: window_start,
         event_ids: Enum.reverse(event_ids)
       }
     }, diagnostics}
  end

  defp evaluate_event(event, running_track_ids, window_start, as_of_date, timezone, state) do
    {total, event_ids, diagnostics} = state

    cond do
      not active?(event) ->
        state

      not running_track_event?(event, running_track_ids) ->
        state

      not in_window?(event, window_start, as_of_date, timezone) ->
        state

      true ->
        case run_amount_km(event) do
          {:ok, amount} ->
            {total + amount, [event_value(event, :id) | event_ids], diagnostics}

          {:error, diagnostic} ->
            {total, event_ids, diagnostics ++ [diagnostic]}
        end
    end
  end

  defp running_track_ids(tracks) do
    tracks
    |> Enum.filter(&running_track?/1)
    |> Enum.map(&track_value(&1, :id))
    |> Enum.reject(&is_nil/1)
    |> MapSet.new()
  end

  defp running_track?(track) do
    target = track_value(track, :target, %{})
    guidance = track_value(track, :guidance, %{})
    records = map_value(target, :records, %{})

    map_value(target, :unit) == "km" or
      map_value(records, :unit) == "km" or
      not is_nil(map_value(guidance, :pace))
  end

  defp running_track_event?(event, running_track_ids) do
    MapSet.member?(running_track_ids, event_value(event, :track_id))
  end

  defp active?(event), do: event_value(event, :status) in [:active, "active"]

  defp in_window?(event, window_start, as_of_date, timezone) do
    case event_date(event, timezone) do
      nil ->
        false

      date ->
        Date.compare(date, window_start) != :lt and Date.compare(date, as_of_date) != :gt
    end
  end

  defp event_date(event, timezone) do
    Improve.Planning.LocalDate.to_date(event_value(event, :effective_at), timezone)
  end

  defp run_amount_km(event) do
    payload = event_value(event, :payload, %{})
    amount = map_value(payload, :amount) || event_value(event, :quantity)
    unit = map_value(payload, :unit) || event_value(event, :unit)

    cond do
      unit != "km" ->
        {:error,
         diagnostic(
           :ignored_recent_load_event,
           "Ignored run event without a km unit.",
           %{event_id: event_value(event, :id), unit: unit}
         )}

      not numeric?(amount) ->
        {:error,
         diagnostic(
           :ignored_recent_load_event,
           "Ignored run event without a numeric km amount.",
           %{event_id: event_value(event, :id), amount: amount}
         )}

      true ->
        {:ok, to_number(amount)}
    end
  end

  defp empty_history_diagnostics([], details) do
    [
      %{
        severity: :info,
        code: :recent_load_no_history,
        message: "No active running history exists in the 7-day load window.",
        details: details
      }
    ]
  end

  defp empty_history_diagnostics(_event_ids, _details), do: []

  defp numeric?(value) when is_integer(value) or is_float(value), do: true
  defp numeric?(%Decimal{}), do: true
  defp numeric?(_value), do: false

  defp to_number(value) when is_integer(value) or is_float(value), do: value * 1.0
  defp to_number(%Decimal{} = value), do: Decimal.to_float(value)

  defp normalize_number(value) when value == trunc(value), do: trunc(value)
  defp normalize_number(value), do: value

  defp diagnostic(code, message, details) do
    %{severity: :warning, code: code, message: message, details: details}
  end

  defp event_value(event, key, default \\ nil), do: map_value(event, key, default)
  defp track_value(track, key, default \\ nil), do: map_value(track, key, default)

  defp map_value(map, key, default \\ nil)

  defp map_value(map, key, default) when is_map(map) do
    Map.get(map, key, Map.get(map, to_string(key), default))
  end

  defp map_value(_value, _key, default), do: default
end
