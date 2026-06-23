defmodule Improve.App do
  @moduledoc """
  Product-facing application workflows.

  This namespace is the place to promote operations that story scripts reveal as
  real UI/API workflows. It should stay above the core domains, while delegating
  persistence, validation, projection, effects, and state derivation to them.
  """

  alias Improve.Journal
  alias Improve.Planning.PathReader
  alias Improve.Plans
  alias Improve.Sessions

  def start_session!(projection, session_key, opts) do
    actor = Keyword.fetch!(opts, :actor)
    template = session_template!(projection.plan_id, session_key, actor)

    projected_occurrence =
      projection.projected_session_occurrences
      |> Enum.find(&(&1.session_template_id == template.id))
      |> case do
        nil -> raise ArgumentError, "No projected session #{inspect(session_key)} exists today."
        projected_occurrence -> projected_occurrence
      end

    Sessions.start_projected_session!(projected_occurrence,
      actor: actor,
      started_at: Keyword.get(opts, :started_at, default_datetime(projection.date)),
      actual_item_ids_by_slot_key: Keyword.get(opts, :actual_item_ids_by_slot_key, %{})
    )
  end

  def log_session_slot!(started_session, opts) do
    actor = Keyword.fetch!(opts, :actor)
    occurrence = Map.fetch!(started_session, :session_occurrence)
    plan_id = occurrence.plan_id
    slot = session_slot!(occurrence, Keyword.fetch!(opts, :slot), actor)
    actual_item = item!(plan_id, Keyword.get(opts, :actual, Keyword.get(opts, :item)), actor)
    recommended_item = maybe_item(plan_id, Keyword.get(opts, :recommended), actor)
    slot_result = slot_result!(started_session, slot, recommended_item, actual_item, actor)
    event_type = event_type!(plan_id, Keyword.fetch!(opts, :event), actor)
    effective_at = Keyword.get(opts, :effective_at, default_datetime(occurrence.planned_for))
    payload = stringify_keys(Keyword.get(opts, :payload, %{}))

    Journal.log_session_item_event!(
      %{
        session_occurrence: occurrence,
        slot_result: slot_result,
        event_type: event_type,
        item: actual_item,
        role: Keyword.get(opts, :role, "exercise"),
        effective_at: effective_at,
        recorded_at: Keyword.get(opts, :recorded_at, effective_at),
        summary: Keyword.get(opts, :summary, session_slot_summary(actual_item, recommended_item)),
        quantity: Keyword.get(opts, :quantity, value(payload, "sets")),
        unit: Keyword.get(opts, :unit, "sets"),
        payload: payload,
        note: Keyword.get(opts, :note, value(payload, "note"))
      },
      actor: actor
    )
  end

  def log_event!(plan, opts) do
    actor = Keyword.fetch!(opts, :actor)
    Journal.log_generic_event!(event_attrs(plan, opts, actor), actor: actor)
  end

  def correct_event!(original_log_or_event, opts) do
    actor = Keyword.fetch!(opts, :actor)
    original_event = event_from(original_log_or_event)
    original_effects = original_effects(original_log_or_event, actor)
    replacement = Keyword.fetch!(opts, :replacement)

    Journal.correct_generic_event!(
      %{
        original_event: original_event,
        original_effects: original_effects,
        corrected_at: Keyword.fetch!(opts, :corrected_at),
        correction_note: Keyword.get(opts, :reason, "Corrected by replacement event"),
        replacement: event_attrs(original_event.plan_id, replacement, actor)
      },
      actor: actor
    )
  end

  def offline_event(plan, opts) do
    actor = Keyword.fetch!(opts, :actor)

    plan
    |> event_attrs(opts, actor)
    |> Map.put(:idempotency, idempotency_attrs(opts))
    |> maybe_put(:origin, Keyword.get(opts, :origin))
    |> maybe_put(:session_occurrence_id, Keyword.get(opts, :session_occurrence_id))
    |> maybe_put(:slot_result_id, Keyword.get(opts, :slot_result_id))
    |> maybe_put(:direct_goal_id, Keyword.get(opts, :direct_goal_id))
  end

  def submit_offline_events!(entries, opts) do
    actor = Keyword.fetch!(opts, :actor)
    Journal.submit_offline_event_batch!(entries, actor: actor)
  end

  def get_item_state!(plan, item_key, opts) do
    actor = Keyword.fetch!(opts, :actor)
    item = item!(plan_id(plan), item_key, actor)
    Journal.get_item_state!(item, actor: actor)
  end

  def log_direct_goal!(projection, opts) do
    actor = Keyword.fetch!(opts, :actor)
    plan_id = projection.plan_id
    direct_goal = direct_goal!(plan_id, Keyword.fetch!(opts, :goal), actor)
    event_type = direct_goal_event_type!(plan_id, direct_goal, opts, actor)
    effective_at = Keyword.get(opts, :effective_at, default_datetime(projection.date))
    payload = stringify_keys(Keyword.get(opts, :payload, %{}))
    quantity = Keyword.get(opts, :quantity, quantity_from_target(payload, direct_goal.target))
    unit = Keyword.get(opts, :unit, value(direct_goal.target, "unit"))
    note = Keyword.get(opts, :note, value(payload, "note"))

    Journal.log_generic_event!(
      %{
        plan_id: plan_id,
        event_type_id: event_type.id,
        direct_goal_id: direct_goal.id,
        effective_at: effective_at,
        recorded_at: Keyword.get(opts, :recorded_at, effective_at),
        summary: Keyword.get(opts, :summary, direct_goal_summary(direct_goal, quantity, unit)),
        payload: payload,
        note: note,
        quantity: quantity,
        unit: unit
      },
      actor: actor
    )
  end

  defp direct_goal_event_type!(plan_id, direct_goal, opts, actor) do
    case Keyword.get(opts, :as_event, Keyword.get(opts, :event)) do
      nil -> Plans.get_event_type!(direct_goal.event_type_id, actor: actor)
      key -> event_type!(plan_id, key, actor)
    end
  end

  defp event_type!(plan_id, key, actor) do
    actor
    |> event_types(plan_id)
    |> Enum.find(&(&1.key == key))
    |> case do
      nil -> raise ArgumentError, "No event type #{inspect(key)} exists in this plan."
      event_type -> event_type
    end
  end

  defp event_attrs(plan, opts, actor) do
    plan_id = plan_id(plan)
    event_type = event_type!(plan_id, Keyword.fetch!(opts, :event), actor)
    payload = stringify_keys(Keyword.get(opts, :payload, %{}))
    links = item_links(plan_id, Keyword.get(opts, :links, %{}), actor)
    effective_at = event_datetime(opts)
    quantity = Keyword.get(opts, :quantity, value(payload, "amount"))
    unit = Keyword.get(opts, :unit, value(payload, "unit"))

    %{
      plan_id: plan_id,
      event_type_id: event_type.id,
      direct_goal_id: direct_goal_id(plan_id, Keyword.get(opts, :goal), actor),
      effective_at: effective_at,
      recorded_at: Keyword.get(opts, :recorded_at, effective_at),
      summary: Keyword.get(opts, :summary, event_summary(event_type, links)),
      quantity: quantity,
      unit: unit,
      payload: payload,
      note: Keyword.get(opts, :note, value(payload, "note")),
      item_links: links
    }
  end

  defp event_from(%{event: event}), do: event
  defp event_from(event), do: event

  defp original_effects(%{item_effects: item_effects}, _actor), do: item_effects

  defp original_effects(%{id: event_id}, actor) do
    Journal.list_item_effects!(
      actor: actor,
      query: [filter: [event_instance_id: event_id]]
    )
  end

  defp idempotency_attrs(opts) do
    %{
      client_event_id: Keyword.fetch!(opts, :client_event_id),
      client_operation_id: Keyword.fetch!(opts, :operation),
      client_device_id: Keyword.get(opts, :device, "story-device"),
      idempotency_key: Keyword.fetch!(opts, :idempotency_key)
    }
  end

  defp item_links(plan_id, links, actor) when is_map(links) do
    Enum.map(links, fn {role, item_key} ->
      item = item!(plan_id, item_key, actor)

      %{
        role: to_string(role),
        item_id: item.id
      }
    end)
  end

  defp event_summary(event_type, [%{role: role, item_id: item_id} | _links]) do
    "#{event_type.name} for #{role} #{item_id}"
  end

  defp event_summary(event_type, _links), do: "#{event_type.name} logged"

  defp session_template!(plan_id, key, actor) do
    actor
    |> session_templates(plan_id)
    |> Enum.find(&(&1.key == to_string(key)))
    |> case do
      nil -> raise ArgumentError, "No session #{inspect(key)} exists in this plan."
      session_template -> session_template
    end
  end

  defp session_slot!(occurrence, key, actor) do
    actor
    |> session_slots(occurrence.plan_id)
    |> Enum.find(&(&1.key == key and &1.session_template_id == occurrence.session_template_id))
    |> case do
      nil -> raise ArgumentError, "No session slot #{inspect(key)} exists in this plan."
      session_slot -> session_slot
    end
  end

  defp item!(plan_id, key, actor) do
    if is_nil(key) do
      raise ArgumentError, "A session slot log needs an item or actual item key."
    end

    actor
    |> items(plan_id)
    |> Enum.find(&(&1.key == key))
    |> case do
      nil -> raise ArgumentError, "No item #{inspect(key)} exists in this plan."
      item -> item
    end
  end

  defp maybe_item(_plan_id, nil, _actor), do: nil
  defp maybe_item(plan_id, key, actor), do: item!(plan_id, key, actor)

  defp slot_result!(started_session, slot, recommended_item, actual_item, actor) do
    occurrence = Map.fetch!(started_session, :session_occurrence)

    actor
    |> slot_results(occurrence.id)
    |> Enum.filter(&(&1.session_slot_id == slot.id))
    |> Enum.filter(&is_nil(&1.event_instance_id))
    |> prefer_recommended(recommended_item)
    |> prefer_actual(actual_item)
    |> case do
      nil ->
        raise ArgumentError,
              "No open slot result exists for slot #{inspect(slot.key)} and item #{inspect(actual_item.key)}."

      slot_result ->
        slot_result
    end
  end

  defp prefer_recommended(slot_results, nil), do: slot_results

  defp prefer_recommended(slot_results, recommended_item) do
    case Enum.filter(slot_results, &(&1.recommended_item_id == recommended_item.id)) do
      [] -> slot_results
      matches -> matches
    end
  end

  defp prefer_actual(slot_results, actual_item) do
    slot_results
    |> Enum.find(&(&1.actual_item_id == actual_item.id))
    |> case do
      nil -> List.first(slot_results)
      slot_result -> slot_result
    end
  end

  defp session_slot_summary(actual_item, nil), do: "#{actual_item.name} performed"

  defp session_slot_summary(actual_item, recommended_item)
       when actual_item.id == recommended_item.id do
    "#{actual_item.name} performed"
  end

  defp session_slot_summary(actual_item, recommended_item) do
    "#{actual_item.name} performed instead of #{recommended_item.name}"
  end

  defp direct_goal!(plan_id, key, actor) do
    actor
    |> direct_goals(plan_id)
    |> Enum.find(&(&1.key == key))
    |> case do
      nil -> raise ArgumentError, "No direct goal #{inspect(key)} exists in this plan."
      direct_goal -> direct_goal
    end
  end

  defp direct_goal_id(_plan_id, nil, _actor), do: nil
  defp direct_goal_id(plan_id, key, actor), do: direct_goal!(plan_id, key, actor).id

  defp event_types(actor, plan_id) do
    Plans.list_event_types!(actor: actor, query: [filter: [plan_id: plan_id]])
  end

  defp session_templates(actor, plan_id) do
    Plans.list_session_templates!(actor: actor, query: [filter: [plan_id: plan_id]])
  end

  defp session_slots(actor, plan_id) do
    Plans.list_session_slots!(actor: actor, query: [filter: [plan_id: plan_id]])
  end

  defp items(actor, plan_id) do
    Plans.list_items!(actor: actor, query: [filter: [plan_id: plan_id]])
  end

  defp slot_results(actor, session_occurrence_id) do
    Sessions.list_slot_results!(
      actor: actor,
      query: [filter: [session_occurrence_id: session_occurrence_id]]
    )
  end

  defp direct_goals(actor, plan_id) do
    Plans.list_direct_goals!(actor: actor, query: [filter: [plan_id: plan_id]])
  end

  defp plan_id(%{id: id}), do: id
  defp plan_id(id), do: id

  defp default_datetime(date) do
    DateTime.new!(date, ~T[20:00:00], "Etc/UTC")
  end

  defp event_datetime(opts) do
    case Keyword.fetch(opts, :effective_at) do
      {:ok, effective_at} -> effective_at
      :error -> default_datetime(Keyword.fetch!(opts, :on))
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp quantity_from_target(payload, target) do
    case value(target, "quantity_path") do
      path when is_binary(path) -> PathReader.value(payload, path)
      _other -> nil
    end
  end

  defp direct_goal_summary(direct_goal, quantity, unit)
       when not is_nil(quantity) and not is_nil(unit) do
    case value(direct_goal.target, "summary_template") do
      template when is_binary(template) ->
        template
        |> String.replace("%{quantity}", to_string(quantity))
        |> String.replace("%{unit}", to_string(unit))

      _other ->
        "#{quantity} #{unit} for #{direct_goal.name}"
    end
  end

  defp direct_goal_summary(direct_goal, _quantity, _unit), do: "#{direct_goal.name} logged"

  defp stringify_keys(value) when is_map(value) do
    Map.new(value, fn {key, value} -> {stringify_key(key), stringify_keys(value)} end)
  end

  defp stringify_keys(value) when is_list(value), do: Enum.map(value, &stringify_keys/1)
  defp stringify_keys(value), do: value

  defp stringify_key(key) when is_atom(key), do: Atom.to_string(key)
  defp stringify_key(key), do: key

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
