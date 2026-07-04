defmodule Improve.Planning.Targets.Progression do
  @moduledoc false

  @behaviour Improve.Planning.Targets.Evaluator

  alias Improve.Planning.LocalDate

  alias Improve.Planning.PathReader

  def target_type, do: "progression"

  def diagnostics(_evaluation), do: []

  def completion(
        %{track: track, plan: plan, date: date, journal_events: journal_events} = evaluation
      ) do
    timezone = Map.get(evaluation, :timezone) || LocalDate.default_timezone()

    expected = expected_quantity(track.target, plan, date)

    entries =
      journal_events
      |> Enum.filter(&completed_event_for?(track, date, timezone, &1))
      |> Enum.map(&quantity_entry(track, &1))
      |> Enum.reject(&is_nil(&1.quantity))

    total = Enum.reduce(entries, Decimal.new(0), &Decimal.add(&2, &1.quantity))

    status =
      if not is_nil(expected.quantity) and Decimal.compare(total, expected.quantity) != :lt do
        :completed
      else
        :incomplete
      end

    {:ok,
     %{
       status: status,
       completed_events: Enum.map(entries, & &1.event),
       progress: progress(entries, total, expected, track)
     }, []}
  end

  defp completed_event_for?(_track, nil, _timezone, _event), do: false

  defp completed_event_for?(track, date, timezone, event) do
    event_value(event, :track_id) == track.id and event_value(event, :status) == :active and
      Date.compare(LocalDate.to_date(event_value(event, :effective_at), timezone), date) == :eq
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

  defp expected_quantity(target, plan, date) do
    progression = target_value(target, "progression") || %{}

    from = decimal(target_value(target, "from") || target_value(progression, "from"))
    to = decimal(target_value(target, "to") || target_value(progression, "to"))

    starts_on =
      target_value(target, "starts_on") || target_value(progression, "starts_on") ||
        plan_value(plan, :starts_on)

    ends_on =
      target_value(target, "ends_on") || target_value(progression, "ends_on") ||
        plan_value(plan, :ends_on)

    %{
      quantity: interpolate(from, to, starts_on, ends_on, date),
      from: from,
      to: to,
      starts_on: starts_on,
      ends_on: ends_on,
      shape: target_value(target, "shape") || target_value(progression, "shape") || "linear"
    }
  end

  defp interpolate(nil, _to, _starts_on, _ends_on, _date), do: nil
  defp interpolate(_from, nil, _starts_on, _ends_on, _date), do: nil
  defp interpolate(_from, _to, nil, _ends_on, _date), do: nil
  defp interpolate(_from, _to, _starts_on, nil, _date), do: nil
  defp interpolate(_from, _to, _starts_on, _ends_on, nil), do: nil

  defp interpolate(from, to, starts_on, ends_on, date) do
    total_days = max(Date.diff(ends_on, starts_on), 0)
    elapsed_days = date |> Date.diff(starts_on) |> min(total_days) |> max(0)

    if total_days == 0 do
      to
    else
      range = Decimal.sub(to, from)
      ratio = Decimal.div(Decimal.new(elapsed_days), Decimal.new(total_days))

      from
      |> Decimal.add(Decimal.mult(range, ratio))
      |> Decimal.round(0, :half_up)
    end
  end

  defp progress(entries, total, expected, track) do
    unit = target_value(track.target, "unit")

    %{
      completed_event_count: length(entries),
      completed_event_ids: Enum.map(entries, & &1.event_id),
      total_quantity: display_number(total),
      expected_quantity: display_number(expected.quantity),
      unit: unit,
      starts_on: expected.starts_on,
      ends_on: expected.ends_on,
      from: display_number(expected.from),
      to: display_number(expected.to),
      shape: stringify(expected.shape),
      label: progression_label(total, expected.quantity, unit)
    }
  end

  defp progression_label(total, expected, unit) do
    "#{display_number(total)} of #{display_number(expected)} #{unit} expected today"
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

  defp stringify(value) when is_atom(value), do: Atom.to_string(value)
  defp stringify(value), do: value

  defp target_value(nil, _key), do: nil
  defp target_value(target, key), do: Map.get(target, key) || Map.get(target, existing_atom(key))

  defp plan_value(nil, _key), do: nil
  defp plan_value(plan, key), do: Map.get(plan, key) || Map.get(plan, to_string(key))

  defp event_value(event, key), do: Map.get(event, key) || Map.get(event, to_string(key))

  defp existing_atom(key) when is_binary(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end
end
