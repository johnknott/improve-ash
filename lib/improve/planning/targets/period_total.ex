defmodule Improve.Planning.Targets.PeriodTotal do
  @moduledoc false

  @behaviour Improve.Planning.Targets.Evaluator

  alias Improve.Planning.LocalDate

  alias Improve.Planning.PathReader

  def target_type, do: "period_total"

  def diagnostics(_evaluation), do: []

  def completion(%{track: track, date: date, journal_events: journal_events} = evaluation) do
    timezone = Map.get(evaluation, :timezone) || LocalDate.default_timezone()

    period = period_for(date, target_value(track.target, "per"))
    target_quantity = decimal(target_value(track.target, "quantity"))

    entries =
      journal_events
      |> Enum.filter(&event_in_period?(track, period, timezone, &1))
      |> Enum.map(&quantity_entry(track, &1))
      |> Enum.reject(&is_nil(&1.quantity))

    total = Enum.reduce(entries, Decimal.new(0), &Decimal.add(&2, &1.quantity))

    status =
      if not is_nil(target_quantity) and Decimal.compare(total, target_quantity) != :lt do
        :completed
      else
        :incomplete
      end

    {:ok,
     %{
       status: status,
       completed_events: Enum.map(entries, & &1.event),
       progress: progress(entries, total, target_quantity, track, period)
     }, []}
  end

  defp period_for(nil, _per), do: nil

  defp period_for(date, per) when per in [:month, "month"] do
    {Date.beginning_of_month(date), Date.end_of_month(date), :month}
  end

  defp period_for(date, _per) do
    {Date.beginning_of_week(date, :monday), Date.end_of_week(date, :monday), :week}
  end

  defp event_in_period?(_track, nil, _timezone, _event), do: false

  defp event_in_period?(track, {starts_on, ends_on, _kind}, timezone, event) do
    event_date = LocalDate.to_date(event_value(event, :effective_at), timezone)

    event_value(event, :track_id) == track.id and event_value(event, :status) == :active and
      Date.compare(event_date, starts_on) != :lt and Date.compare(event_date, ends_on) != :gt
  end

  defp quantity_entry(track, event) do
    quantity =
      event_value(event, :quantity) ||
        payload_value(event, target_value(track.target, "quantity_path")) ||
        payload_value(event, "payload.amount")

    %{
      event: event,
      event_id: event_value(event, :id),
      quantity: decimal(quantity)
    }
  end

  defp progress(entries, total, target_quantity, track, {starts_on, ends_on, period_kind}) do
    unit = target_value(track.target, "unit")

    %{
      completed_event_count: length(entries),
      completed_event_ids: Enum.map(entries, & &1.event_id),
      total_quantity: display_number(total),
      target_quantity: display_number(target_quantity),
      unit: unit,
      period: period_kind,
      starts_on: starts_on,
      ends_on: ends_on,
      label: period_label(total, target_quantity, unit, period_kind)
    }
  end

  defp progress(_entries, total, target_quantity, track, nil) do
    %{
      completed_event_count: 0,
      completed_event_ids: [],
      total_quantity: display_number(total),
      target_quantity: display_number(target_quantity),
      unit: target_value(track.target, "unit"),
      period: nil,
      starts_on: nil,
      ends_on: nil,
      label: "No period available"
    }
  end

  defp period_label(total, target_quantity, unit, period_kind) do
    period = if period_kind == :month, do: "this month", else: "this week"
    "#{display_number(total)} of #{display_number(target_quantity)} #{unit} #{period}"
  end

  defp payload_value(event, path) when is_binary(path) do
    event
    |> event_value(:payload)
    |> PathReader.value(path)
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
    value
    |> Decimal.normalize()
    |> Decimal.to_string(:normal)
  end

  defp target_value(target, key), do: Map.get(target, key) || Map.get(target, existing_atom(key))

  defp event_value(event, key), do: Map.get(event, key) || Map.get(event, to_string(key))

  defp existing_atom(key) when is_binary(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end
end
