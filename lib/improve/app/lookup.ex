defmodule Improve.App.Lookup do
  @moduledoc false

  alias Improve.Plans
  alias Improve.Sessions

  def event_type!(plan_or_id, key, actor) do
    actor
    |> event_types(plan_id(plan_or_id))
    |> Enum.find(&(&1.key == to_string(key)))
    |> case do
      nil -> raise ArgumentError, "No event type #{inspect(key)} exists in this plan."
      event_type -> event_type
    end
  end

  def item_type!(plan_or_id, key, actor) do
    actor
    |> item_types(plan_id(plan_or_id))
    |> Enum.find(&(&1.key == to_string(key)))
    |> case do
      nil -> raise ArgumentError, "No item type #{inspect(key)} exists in this plan."
      item_type -> item_type
    end
  end

  def item!(plan_or_id, key, actor) do
    if is_nil(key) do
      raise ArgumentError, "An item key is required."
    end

    actor
    |> items(plan_id(plan_or_id))
    |> Enum.find(&(&1.key == to_string(key)))
    |> case do
      nil -> raise ArgumentError, "No item #{inspect(key)} exists in this plan."
      item -> item
    end
  end

  def pool!(plan_or_id, key, actor) do
    actor
    |> pools(plan_id(plan_or_id))
    |> Enum.find(&(&1.key == to_string(key)))
    |> case do
      nil -> raise ArgumentError, "No pool #{inspect(key)} exists in this plan."
      pool -> pool
    end
  end

  def track!(plan_or_id, key, actor) do
    actor
    |> tracks(plan_id(plan_or_id))
    |> Enum.find(&(&1.key == to_string(key)))
    |> case do
      nil -> raise ArgumentError, "No track #{inspect(key)} exists in this plan."
      track -> track
    end
  end

  def session_template!(plan_or_id, key, actor) do
    actor
    |> session_templates(plan_id(plan_or_id))
    |> Enum.find(&(&1.key == to_string(key)))
    |> case do
      nil -> raise ArgumentError, "No session #{inspect(key)} exists in this plan."
      session_template -> session_template
    end
  end

  def session_slot!(occurrence, key, actor) do
    actor
    |> session_slots(occurrence.plan_id)
    |> Enum.find(
      &(&1.key == to_string(key) and &1.session_template_id == occurrence.session_template_id)
    )
    |> case do
      nil -> raise ArgumentError, "No session slot #{inspect(key)} exists in this plan."
      session_slot -> session_slot
    end
  end

  def event_types(actor, plan_or_id) do
    Plans.list_event_types!(actor: actor, query: [filter: [plan_id: plan_id(plan_or_id)]])
  end

  def item_types(actor, plan_or_id) do
    Plans.list_item_types!(actor: actor, query: [filter: [plan_id: plan_id(plan_or_id)]])
  end

  def items(actor, plan_or_id) do
    Plans.list_items!(actor: actor, query: [filter: [plan_id: plan_id(plan_or_id)]])
  end

  def pools(actor, plan_or_id) do
    Plans.list_pools!(actor: actor, query: [filter: [plan_id: plan_id(plan_or_id)]])
  end

  def tracks(actor, plan_or_id) do
    Plans.list_tracks!(actor: actor, query: [filter: [plan_id: plan_id(plan_or_id)]])
  end

  def session_templates(actor, plan_or_id) do
    Plans.list_session_templates!(actor: actor, query: [filter: [plan_id: plan_id(plan_or_id)]])
  end

  def session_slots(actor, plan_or_id) do
    Plans.list_session_slots!(actor: actor, query: [filter: [plan_id: plan_id(plan_or_id)]])
  end

  def slot_results(actor, session_occurrence_id) do
    Sessions.list_slot_results!(
      actor: actor,
      query: [filter: [session_occurrence_id: session_occurrence_id]]
    )
  end

  def plan_id(%{id: id}), do: id
  def plan_id(id), do: id
end
