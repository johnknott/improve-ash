defmodule Improve.Planning.Targets.Metric do
  @moduledoc false

  @behaviour Improve.Planning.Targets.Evaluator

  alias Improve.Planning.PathReader

  def target_type, do: "metric"

  def diagnostics(_evaluation), do: []

  def completion(%{track: track, date: date, journal_events: journal_events}) do
    recorded =
      journal_events
      |> Enum.filter(&completed_event_for?(track, date, &1))
      |> Enum.map(&recorded_value(track, &1))
      |> Enum.reject(&is_nil(&1.value))

    status =
      case recorded do
        [_value | _values] -> :completed
        [] -> :incomplete
      end

    {:ok,
     %{
       status: status,
       completed_events: Enum.map(recorded, & &1.event),
       progress: progress(recorded, track)
     }, []}
  end

  defp completed_event_for?(_track, nil, _event), do: false

  defp completed_event_for?(track, date, event) do
    event_value(event, :track_id) == track.id and event_value(event, :status) == :active and
      Date.compare(DateTime.to_date(event_value(event, :effective_at)), date) == :eq
  end

  defp recorded_value(track, event) do
    value =
      event_value(event, :quantity) ||
        payload_value(event, target_value(track.target, "quantity_path")) ||
        payload_value(event, "payload.amount") ||
        payload_value(event, "payload.value")

    unit = target_value(track.target, "unit") || event_value(event, :unit)

    %{
      event: event,
      event_id: event_value(event, :id),
      value: value,
      unit: unit
    }
  end

  defp progress([], track) do
    %{
      completed_event_count: 0,
      completed_event_ids: [],
      recorded_value: nil,
      unit: target_value(track.target, "unit"),
      label: "No value recorded"
    }
  end

  defp progress(recorded, _track) do
    latest = List.last(recorded)

    %{
      completed_event_count: length(recorded),
      completed_event_ids: Enum.map(recorded, & &1.event_id),
      recorded_value: latest.value,
      unit: latest.unit,
      label: metric_label(latest.value, latest.unit)
    }
  end

  defp metric_label(value, nil), do: "Recorded #{value}"
  defp metric_label(value, unit), do: "Recorded #{value} #{unit}"

  defp payload_value(event, path) when is_binary(path) do
    event
    |> event_value(:payload)
    |> PathReader.value(path)
  end

  defp payload_value(_event, _path), do: nil

  defp target_value(target, key), do: Map.get(target, key) || Map.get(target, existing_atom(key))

  defp event_value(event, key), do: Map.get(event, key) || Map.get(event, to_string(key))

  defp existing_atom(key) when is_binary(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end
end
