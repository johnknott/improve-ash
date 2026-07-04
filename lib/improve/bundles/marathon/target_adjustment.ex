defmodule Improve.Bundles.Marathon.TargetAdjustment do
  @moduledoc """
  Derives target adjustments for marathon tracks based on recent load and life events.

  Emits a map of `{track_id => %{values: ..., source: ..., reason: ...}}` that the
  projector uses to build effective targets. Adjustments are ephemeral (derived per
  projection, not persisted) — they represent today's adapted reality.
  """

  @low_load_threshold_fraction Decimal.new("0.6")

  def evaluate(input) when is_map(input) do
    adjustments = build_adjustments(input)
    {:ok, %{derived_target_adjustments: adjustments}, []}
  end

  defp build_adjustments(input) do
    tracks = Map.get(input, :tracks, [])
    recent_load = input |> Map.get(:recent_load_km, %{}) |> map_value(:value, 0)
    life_events = Map.get(input, :life_events, [])
    date = Map.fetch!(input, :date)

    tracks
    |> Enum.filter(&period_total_track?/1)
    |> Enum.reduce(%{}, fn track, acc ->
      case adjustment_for(track, recent_load, life_events, date) do
        nil -> acc
        adjustment -> Map.put(acc, track.id, adjustment)
      end
    end)
  end

  defp adjustment_for(track, recent_load, life_events, date) do
    cond do
      recent_illness?(life_events, date) ->
        illness_adjustment(track)

      recent_injury?(life_events, date) ->
        injury_adjustment(track)

      low_recent_load?(track, recent_load) ->
        load_adjustment(track, recent_load)

      true ->
        nil
    end
  end

  defp illness_adjustment(track) do
    target_quantity = track_quantity(track)

    if target_quantity do
      reduced = Decimal.mult(target_quantity, Decimal.new("0.5")) |> Decimal.round(0, :half_up)

      %{
        values: %{"quantity" => Decimal.to_string(reduced)},
        source: :illness_deload,
        reason: "Target reduced by 50% after recent illness"
      }
    end
  end

  defp injury_adjustment(track) do
    target_quantity = track_quantity(track)

    if target_quantity do
      reduced = Decimal.mult(target_quantity, Decimal.new("0.5")) |> Decimal.round(0, :half_up)

      %{
        values: %{"quantity" => Decimal.to_string(reduced)},
        source: :injury_deload,
        reason: "Target reduced by 50% while injury is active"
      }
    end
  end

  defp load_adjustment(track, recent_load) do
    target_quantity = track_quantity(track)

    if target_quantity do
      ratio =
        if Decimal.compare(target_quantity, Decimal.new(0)) == :gt do
          Decimal.div(Decimal.new(recent_load), target_quantity)
        else
          Decimal.new(1)
        end

      if Decimal.compare(ratio, @low_load_threshold_fraction) == :lt do
        midpoint =
          Decimal.add(Decimal.new(recent_load), target_quantity)
          |> Decimal.div(Decimal.new(2))
          |> Decimal.round(0, :half_up)

        %{
          values: %{"quantity" => Decimal.to_string(midpoint)},
          source: :low_load_adaptation,
          reason: "Target adjusted down because recent load (#{recent_load}km) is well below plan"
        }
      end
    end
  end

  defp period_total_track?(track) do
    target = Map.get(track, :target, %{})
    target_type(target) == "period_total"
  end

  defp track_quantity(track) do
    quantity = get_in(track, [:target, "quantity"]) || get_in(track, [:target, :quantity])
    decimal(quantity)
  end

  defp target_type(target) do
    Map.get(target, "type") || Map.get(target, :type)
  end

  defp recent_illness?(life_events, date) do
    Enum.any?(life_events, fn event ->
      event_type(event) == :illness and event_recent?(event, date, 3)
    end)
  end

  defp recent_injury?(life_events, date) do
    Enum.any?(life_events, fn event ->
      event_type(event) == :injury and event_active_on?(event, date)
    end)
  end

  defp low_recent_load?(track, recent_load) do
    target_quantity = track_quantity(track)

    target_quantity && recent_load > 0 &&
      Decimal.compare(
        Decimal.new(recent_load),
        Decimal.mult(target_quantity, @low_load_threshold_fraction)
      ) == :lt
  end

  defp event_type(event), do: map_value(event, :type) || map_value(event, :event_type_key)

  defp event_recent?(event, date, days) do
    ends_on = map_value(event, :to) || map_value(event, :ends_on)
    ends_on && Date.diff(date, ends_on) in 0..days
  end

  defp event_active_on?(event, date) do
    starts_on = map_value(event, :from) || map_value(event, :starts_on) || date
    ends_on = map_value(event, :to) || map_value(event, :ends_on)

    Date.compare(date, starts_on) != :lt and
      (is_nil(ends_on) or Date.compare(date, ends_on) != :gt)
  end

  defp decimal(nil), do: nil
  defp decimal(%Decimal{} = d), do: d
  defp decimal(n) when is_integer(n), do: Decimal.new(n)
  defp decimal(n) when is_float(n), do: Decimal.from_float(n)

  defp decimal(s) when is_binary(s) do
    case Decimal.parse(s) do
      {d, ""} -> d
      _ -> nil
    end
  end

  defp decimal(_), do: nil

  defp map_value(map, key, default \\ nil) when is_map(map) do
    Map.get(map, key, Map.get(map, to_string(key), default))
  end
end
