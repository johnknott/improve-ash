defmodule Improve.Planning.Targets.Checklist do
  @moduledoc false

  @behaviour Improve.Planning.Targets.Evaluator

  alias Improve.Planning.LocalDate

  def target_type, do: "checklist"

  def diagnostics(_evaluation), do: []

  def completion(%{track: track, date: date, journal_events: journal_events} = evaluation) do
    timezone = Map.get(evaluation, :timezone) || LocalDate.default_timezone()

    required_items = checklist_items(track.target)

    completed_events =
      journal_events
      |> Enum.filter(&completed_event_for?(track, date, timezone, &1))

    completed_items =
      completed_events
      |> Enum.flat_map(&event_completed_items/1)
      |> MapSet.new()

    required_keys = MapSet.new(Enum.map(required_items, & &1.key))
    completed_required = MapSet.intersection(required_keys, completed_items)

    status =
      cond do
        MapSet.size(required_keys) == 0 -> :incomplete
        MapSet.equal?(completed_required, required_keys) -> :completed
        true -> :incomplete
      end

    {:ok,
     %{
       status: status,
       completed_events: completed_events,
       progress: progress(required_items, completed_required, completed_events)
     }, []}
  end

  defp completed_event_for?(_track, nil, _timezone, _event), do: false

  defp completed_event_for?(track, date, timezone, event) do
    event_value(event, :track_id) == track.id and event_value(event, :status) == :active and
      Date.compare(LocalDate.to_date(event_value(event, :effective_at), timezone), date) == :eq
  end

  defp checklist_items(target) do
    target
    |> target_value("items")
    |> case do
      items when is_list(items) -> Enum.map(items, &checklist_item/1)
      _other -> target_value(target, "checklist_items") || []
    end
    |> Enum.map(&checklist_item/1)
  end

  defp checklist_item(%{"key" => key, "label" => label}), do: %{key: to_string(key), label: label}
  defp checklist_item(%{key: key, label: label}), do: %{key: to_string(key), label: label}

  defp checklist_item(item) when is_binary(item) do
    %{key: item, label: item}
  end

  defp checklist_item(item), do: %{key: to_string(item), label: to_string(item)}

  defp event_completed_items(event) do
    payload = event_value(event, :payload) || %{}

    (payload_value(payload, "checked_items") || payload_value(payload, "completed_items") ||
       payload_value(payload, "items") || [])
    |> List.wrap()
    |> Enum.map(&completed_item_key/1)
  end

  defp completed_item_key(%{"key" => key}), do: to_string(key)
  defp completed_item_key(%{key: key}), do: to_string(key)
  defp completed_item_key(item), do: to_string(item)

  defp progress(required_items, completed_required, completed_events) do
    completed_count = MapSet.size(completed_required)
    required_count = length(required_items)

    %{
      completed_event_count: length(completed_events),
      completed_event_ids: Enum.map(completed_events, &event_value(&1, :id)),
      completed_count: completed_count,
      required_count: required_count,
      completed_items: Enum.sort(MapSet.to_list(completed_required)),
      required_items: Enum.map(required_items, & &1.key),
      label: "#{completed_count} of #{required_count} complete"
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
