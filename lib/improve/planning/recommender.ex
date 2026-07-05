defmodule Improve.Planning.Recommender do
  @moduledoc """
  Deterministic item recommendations for projected session slots.

  This module is pure: callers pass all candidate records explicitly.
  """

  def recommend_slot(slot, input) do
    pool_memberships = Map.fetch!(input, :pool_memberships)
    items = Map.fetch!(input, :items)
    environment = Map.get(input, :environment)
    recent_item_ids = Map.get(input, :recent_item_ids, [])
    journal_events = Map.get(input, :journal_events, [])

    available_ids = available_item_ids(environment)
    pool_item_ids = pool_item_ids(pool_memberships, slot.pool_id)

    items
    |> Enum.filter(&(&1.id in pool_item_ids))
    |> Enum.filter(&available_in_environment?(&1, available_ids))
    |> Enum.reject(&archived?/1)
    |> Enum.sort_by(&sort_key(&1, recent_item_ids))
    |> Enum.take(slot.count)
    |> Enum.map(&item_projection(&1, slot, journal_events))
  end

  defp pool_item_ids(pool_memberships, pool_id) do
    pool_memberships
    |> Enum.filter(&(&1.pool_id == pool_id))
    |> Enum.map(& &1.item_id)
  end

  defp available_item_ids(nil), do: :all
  defp available_item_ids(%{available_item_ids: []}), do: :all
  defp available_item_ids(%{available_item_ids: ids}), do: MapSet.new(ids)

  defp available_in_environment?(_item, :all), do: true
  defp available_in_environment?(item, available_ids), do: MapSet.member?(available_ids, item.id)

  defp archived?(%{archived_at: nil}), do: false
  defp archived?(%{archived_at: _archived_at}), do: true
  defp archived?(_item), do: false

  defp sort_key(item, recent_item_ids) do
    recent_position =
      case Enum.find_index(recent_item_ids, &(&1 == item.id)) do
        nil -> -1
        index -> index
      end

    {recent_position, item.key, item.name}
  end

  defp item_projection(item, slot, journal_events) do
    suggestion = suggestion(item, slot, journal_events)

    %{
      item_id: item.id,
      item_key: item.key,
      item_name: item.name,
      suggested_payload: suggestion.payload,
      reason: suggestion.reason,
      source: suggestion.source,
      previous_event_ids: Enum.map(suggestion.previous_events, & &1.id),
      previous_events: Enum.map(suggestion.previous_events, &previous_event_projection/1)
    }
  end

  defp suggestion(item, slot, journal_events) do
    adaptive_target = adaptive_target(slot)
    previous_events = previous_events(item.id, journal_events)

    cond do
      adaptive_target && previous_events != [] ->
        payload = history_payload(List.first(previous_events), adaptive_target)

        if payload == %{} do
          cold_start_suggestion(slot, previous_events)
        else
          %{
            payload: payload,
            reason: "Based on your last #{slot.name} entry.",
            source: "history",
            previous_events: previous_events
          }
        end

      adaptive_target ->
        cold_start_suggestion(slot, [])

      manual_payload(slot) != %{} ->
        %{
          payload: manual_payload(slot),
          reason: "The plan's usual starting point.",
          source: "manual_rule",
          previous_events: []
        }

      true ->
        %{
          payload: %{},
          reason: recommendation_reason(slot),
          source: "deterministic_slot_recommendation",
          previous_events: []
        }
    end
  end

  defp cold_start_suggestion(slot, previous_events) do
    %{
      payload: cold_start_payload(slot),
      reason: "A starting suggestion — adjust as you go.",
      source: "cold_start",
      previous_events: previous_events
    }
  end

  defp adaptive_target(slot) do
    target = rule(slot, "suggestion_target") || rule(slot, "target")

    case value(target, "type") do
      :adaptive -> target
      "adaptive" -> target
      _other -> nil
    end
  end

  defp cold_start_payload(slot) do
    rule(slot, "cold_start_payload") || rule(slot, "start_with") || manual_payload(slot)
  end

  defp manual_payload(slot),
    do: rule(slot, "suggested_payload") || rule(slot, "default_payload") || %{}

  defp history_payload(event, target) do
    target
    |> suggestion_fields()
    |> Enum.reduce(%{}, fn field, payload ->
      case value(event.payload || %{}, field) do
        nil -> payload
        value -> Map.put(payload, field, value)
      end
    end)
  end

  defp suggestion_fields(target) do
    fields = value(target, "fields") || []
    effort = value(target, "effort")

    (fields ++ List.wrap(effort))
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&to_string/1)
    |> Enum.uniq()
  end

  defp previous_events(item_id, journal_events) do
    journal_events
    |> Enum.filter(&active_event?/1)
    |> Enum.filter(&linked_to_item?(&1, item_id))
    |> Enum.sort_by(&event_sort_key/1, :desc)
    |> Enum.take(3)
  end

  defp active_event?(%{status: :active}), do: true
  defp active_event?(%{status: "active"}), do: true
  defp active_event?(_event), do: false

  defp linked_to_item?(event, item_id) do
    event
    |> Map.get(:event_item_links, [])
    |> Enum.any?(&(&1.item_id == item_id))
  end

  defp event_sort_key(event), do: {event.effective_at, event.recorded_at, event.id}

  defp previous_event_projection(event) do
    %{
      id: event.id,
      summary: event.summary,
      effective_at: datetime_string(event.effective_at),
      payload: event.payload || %{}
    }
  end

  defp datetime_string(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
  defp datetime_string(value), do: value

  defp recommendation_reason(slot) do
    "Picked from the #{slot.name} pool, favouring variety."
  end

  defp rule(slot, key), do: value(slot.rules || %{}, key)

  defp value(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, existing_atom(key))
  end

  defp value(_map, _key), do: nil

  defp existing_atom(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end
end
