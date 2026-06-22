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

    available_ids = available_item_ids(environment)
    pool_item_ids = pool_item_ids(pool_memberships, slot.pool_id)

    items
    |> Enum.filter(&(&1.id in pool_item_ids))
    |> Enum.filter(&available_in_environment?(&1, available_ids))
    |> Enum.reject(&archived?/1)
    |> Enum.sort_by(&sort_key(&1, recent_item_ids))
    |> Enum.take(slot.count)
    |> Enum.map(&item_projection/1)
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

  defp item_projection(item) do
    %{
      item_id: item.id,
      item_key: item.key,
      item_name: item.name
    }
  end
end
