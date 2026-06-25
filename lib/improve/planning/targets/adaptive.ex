defmodule Improve.Planning.Targets.Adaptive do
  @moduledoc false

  @behaviour Improve.Planning.Targets.Evaluator

  def target_type, do: "adaptive"

  def diagnostics(_evaluation), do: []

  def completion(%{track: track, date: date, journal_events: journal_events}) do
    required_fields = required_fields(track.target)

    contributing_events =
      journal_events
      |> Enum.filter(&completed_event_for?(track, date, &1))
      |> Enum.map(&event_progress(required_fields, &1))
      |> Enum.reject(&(&1.recorded_fields == []))

    recorded_fields =
      contributing_events
      |> Enum.flat_map(& &1.recorded_fields)
      |> Enum.uniq()

    missing_fields = required_fields -- recorded_fields

    status =
      cond do
        required_fields == [] -> :incomplete
        missing_fields == [] -> :completed
        true -> :incomplete
      end

    {:ok,
     %{
       status: status,
       completed_events: Enum.map(contributing_events, & &1.event),
       progress: progress(required_fields, recorded_fields, missing_fields, contributing_events)
     }, []}
  end

  defp completed_event_for?(_track, nil, _event), do: false

  defp completed_event_for?(track, date, event) do
    event_value(event, :track_id) == track.id and event_value(event, :status) == :active and
      Date.compare(DateTime.to_date(event_value(event, :effective_at)), date) == :eq
  end

  defp required_fields(target) do
    fields = target_value(target, "fields") || []
    effort = target_value(target, "effort")

    (fields ++ List.wrap(effort))
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&to_string/1)
    |> Enum.uniq()
  end

  defp event_progress(required_fields, event) do
    payload = event_value(event, :payload) || %{}

    recorded_fields =
      Enum.filter(required_fields, fn field ->
        not is_nil(payload_value(payload, field))
      end)

    %{event: event, event_id: event_value(event, :id), recorded_fields: recorded_fields}
  end

  defp progress(required_fields, recorded_fields, missing_fields, contributing_events) do
    %{
      completed_event_count: length(contributing_events),
      completed_event_ids: Enum.map(contributing_events, & &1.event_id),
      required_fields: required_fields,
      recorded_fields: recorded_fields,
      missing_fields: missing_fields,
      recorded_count: length(recorded_fields),
      required_count: length(required_fields),
      label: "#{length(recorded_fields)} of #{length(required_fields)} adaptive fields recorded"
    }
  end

  defp target_value(target, key), do: Map.get(target, key) || Map.get(target, existing_atom(key))

  defp payload_value(payload, key),
    do: Map.get(payload, key) || Map.get(payload, existing_atom(key))

  defp event_value(event, key), do: Map.get(event, key) || Map.get(event, to_string(key))

  defp existing_atom(key) when is_binary(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end
end
