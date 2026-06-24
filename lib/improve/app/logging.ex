defmodule Improve.App.Logging do
  @moduledoc """
  Product-facing logging, correction, and offline-ingress workflows.
  """

  alias Improve.App.Lookup
  alias Improve.App.Value
  alias Improve.Journal
  alias Improve.Planning.PathReader
  alias Improve.Plans
  alias Improve.Sessions

  def start_session!(projection, session_key, opts) do
    actor = Keyword.fetch!(opts, :actor)
    template = Lookup.session_template!(projection.plan_id, session_key, actor)

    projected_occurrence =
      projection.projected_session_occurrences
      |> Enum.find(&(&1.session_template_id == template.id))
      |> case do
        nil -> raise ArgumentError, "No projected session #{inspect(session_key)} exists today."
        projected_occurrence -> projected_occurrence
      end

    Sessions.start_projected_session!(projected_occurrence,
      actor: actor,
      started_at: Keyword.get(opts, :started_at, Value.default_datetime(projection.date)),
      actual_item_ids_by_slot_key: Keyword.get(opts, :actual_item_ids_by_slot_key, %{})
    )
  end

  def log_session_slot!(started_session, opts) do
    actor = Keyword.fetch!(opts, :actor)
    occurrence = Map.fetch!(started_session, :session_occurrence)
    plan_id = occurrence.plan_id
    slot = Lookup.session_slot!(occurrence, Keyword.fetch!(opts, :slot), actor)

    actual_item =
      Lookup.item!(plan_id, Keyword.get(opts, :actual, Keyword.get(opts, :item)), actor)

    recommended_item = maybe_item(plan_id, Keyword.get(opts, :recommended), actor)
    slot_result = slot_result!(started_session, slot, recommended_item, actual_item, actor)
    event_type = Lookup.event_type!(plan_id, event_key!(slot, opts), actor)

    effective_at =
      Keyword.get(opts, :effective_at, Value.default_datetime(occurrence.planned_for))

    payload = slot_payload(slot, opts)

    result =
      Journal.log_session_item_event!(
        %{
          session_occurrence: occurrence,
          slot_result: slot_result,
          event_type: event_type,
          item: actual_item,
          role:
            Keyword.get(
              opts,
              :role,
              Value.value(slot.rules, "default_role") || default_role!(event_type)
            ),
          effective_at: effective_at,
          recorded_at: Keyword.get(opts, :recorded_at, effective_at),
          summary:
            Keyword.get(opts, :summary, session_slot_summary(actual_item, recommended_item)),
          quantity: Keyword.get(opts, :quantity, generic_quantity(payload)),
          unit: Keyword.get(opts, :unit, Value.value(payload, "unit")),
          payload: payload,
          note: Keyword.get(opts, :note, Value.value(payload, "note"))
        },
        actor: actor
      )

    Map.put(result, :event_item_links, [result.event_item_link])
  end

  def skip_session_slot!(started_session, opts) do
    actor = Keyword.fetch!(opts, :actor)
    occurrence = Map.fetch!(started_session, :session_occurrence)
    plan_id = occurrence.plan_id
    slot = Lookup.session_slot!(occurrence, Keyword.fetch!(opts, :slot), actor)
    recommended_item = maybe_item(plan_id, Keyword.get(opts, :recommended), actor)
    slot_result = skippable_slot_result!(started_session, slot, recommended_item, actor)

    Sessions.skip_slot_result!(
      slot_result,
      %{
        actual_payload: Value.stringify_keys(Keyword.get(opts, :payload, %{})),
        notes: Keyword.get(opts, :note, Keyword.get(opts, :notes))
      },
      actor: actor
    )
  end

  def log_event!(plan, opts) do
    actor = Keyword.fetch!(opts, :actor)
    Journal.log_generic_event!(event_attrs(plan, opts, actor), actor: actor)
  end

  def log_track!(projection, opts) do
    actor = Keyword.fetch!(opts, :actor)
    plan_id = projection.plan_id
    track = Lookup.track!(plan_id, Keyword.fetch!(opts, :track), actor)
    event_type = track_event_type!(plan_id, track, opts, actor)
    effective_at = Keyword.get(opts, :effective_at, Value.default_datetime(projection.date))
    payload = Value.stringify_keys(Keyword.get(opts, :payload, %{}))
    quantity = Keyword.get(opts, :quantity, quantity_from_target(payload, track.target))
    unit = Keyword.get(opts, :unit, Value.value(track.target, "unit"))
    note = Keyword.get(opts, :note, Value.value(payload, "note"))
    links = item_links(plan_id, merged_links(track, opts), actor)

    Journal.log_generic_event!(
      %{
        plan_id: plan_id,
        event_type_id: event_type.id,
        track_id: track.id,
        effective_at: effective_at,
        recorded_at: Keyword.get(opts, :recorded_at, effective_at),
        summary: Keyword.get(opts, :summary, track_summary(track, quantity, unit)),
        payload: payload,
        note: note,
        quantity: quantity,
        unit: unit,
        item_links: links
      },
      actor: actor
    )
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

  def build_offline_event(plan, opts) do
    actor = Keyword.fetch!(opts, :actor)

    plan
    |> event_attrs(opts, actor)
    |> Map.put(:idempotency, idempotency_attrs(opts))
    |> Value.maybe_put(:origin, Keyword.get(opts, :origin))
    |> Value.maybe_put(:session_occurrence_id, Keyword.get(opts, :session_occurrence_id))
    |> Value.maybe_put(:slot_result_id, Keyword.get(opts, :slot_result_id))
    |> Value.maybe_put(:track_id, Keyword.get(opts, :track_id))
  end

  def submit_offline_events!(entries, opts) do
    Journal.submit_offline_event_batch!(entries, actor: Keyword.fetch!(opts, :actor))
  end

  def event_attrs(plan, opts, actor) do
    plan_id = Lookup.plan_id(plan)
    track = maybe_track(plan_id, Keyword.get(opts, :track), actor)
    event_type = event_type!(plan_id, track, opts, actor)
    payload = Value.stringify_keys(Keyword.get(opts, :payload, %{}))
    links = item_links(plan_id, merged_links(track, opts), actor)
    effective_at = event_datetime(opts)
    quantity = Keyword.get(opts, :quantity, quantity_from_event(payload, track))
    unit = Keyword.get(opts, :unit, unit_from_event(payload, track))

    %{
      plan_id: plan_id,
      event_type_id: event_type.id,
      track_id: if(track, do: track.id),
      effective_at: effective_at,
      recorded_at: Keyword.get(opts, :recorded_at, effective_at),
      summary:
        Keyword.get(opts, :summary, event_summary(event_type, links, track, quantity, unit)),
      quantity: quantity,
      unit: unit,
      payload: payload,
      note: Keyword.get(opts, :note, Value.value(payload, "note")),
      item_links: links
    }
  end

  defp maybe_item(_plan_id, nil, _actor), do: nil
  defp maybe_item(plan_id, key, actor), do: Lookup.item!(plan_id, key, actor)

  defp slot_result!(started_session, slot, recommended_item, actual_item, actor) do
    occurrence = Map.fetch!(started_session, :session_occurrence)

    actor
    |> Lookup.slot_results(occurrence.id)
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

  defp skippable_slot_result!(started_session, slot, recommended_item, actor) do
    occurrence = Map.fetch!(started_session, :session_occurrence)

    actor
    |> Lookup.slot_results(occurrence.id)
    |> Enum.filter(&(&1.session_slot_id == slot.id))
    |> Enum.filter(&is_nil(&1.event_instance_id))
    |> prefer_recommended(recommended_item)
    |> List.first()
    |> case do
      nil -> raise ArgumentError, "No open slot result exists for slot #{inspect(slot.key)}."
      slot_result -> slot_result
    end
  end

  defp event_key!(slot, opts) do
    Keyword.get(opts, :event) || Value.value(slot.rules, "default_event") ||
      raise ArgumentError, "A session slot log needs an event key or slot default_event rule."
  end

  defp default_role!(event_type) do
    case event_type.item_link_roles |> Value.value("roles") do
      roles when is_list(roles) ->
        roles
        |> Enum.find(&Value.value(&1, "required"))
        |> Kernel.||(List.first(roles))
        |> Value.value("role")

      _other ->
        nil
    end ||
      raise(ArgumentError, "A session slot log needs an item link role.")
  end

  defp slot_payload(slot, opts) do
    slot.rules
    |> Value.value("default_payload")
    |> case do
      payload when is_map(payload) -> payload
      _other -> %{}
    end
    |> Map.merge(Value.stringify_keys(Keyword.get(opts, :payload, %{})))
  end

  defp generic_quantity(payload) do
    Value.value(payload, "amount") || Value.value(payload, "quantity")
  end

  defp session_slot_summary(actual_item, nil), do: "#{actual_item.name} performed"

  defp session_slot_summary(actual_item, recommended_item)
       when actual_item.id == recommended_item.id do
    "#{actual_item.name} performed"
  end

  defp session_slot_summary(actual_item, recommended_item) do
    "#{actual_item.name} performed instead of #{recommended_item.name}"
  end

  defp track_event_type!(plan_id, track, opts, actor) do
    case Keyword.get(opts, :as_event, Keyword.get(opts, :event)) do
      nil -> Plans.get_event_type!(track.event_type_id, actor: actor)
      key -> Lookup.event_type!(plan_id, key, actor)
    end
  end

  defp event_type!(plan_id, nil, opts, actor),
    do: Lookup.event_type!(plan_id, Keyword.fetch!(opts, :event), actor)

  defp event_type!(plan_id, track, opts, actor) do
    case Keyword.get(opts, :event) do
      nil -> Plans.get_event_type!(track.event_type_id, actor: actor)
      key -> Lookup.event_type!(plan_id, key, actor)
    end
  end

  defp maybe_track(_plan_id, nil, _actor), do: nil
  defp maybe_track(plan_id, key, actor), do: Lookup.track!(plan_id, key, actor)

  defp merged_links(nil, opts), do: Value.stringify_keys(Keyword.get(opts, :links, %{}))

  defp merged_links(track, opts) do
    track
    |> default_links()
    |> Map.merge(Value.stringify_keys(Keyword.get(opts, :links, %{})))
  end

  defp default_links(track) do
    case Value.value(track.target, "default_links") do
      links when is_map(links) -> Value.stringify_keys(links)
      _other -> %{}
    end
  end

  defp item_links(plan_id, links, actor) when is_map(links) do
    Enum.map(links, fn {role, item_key} ->
      item = Lookup.item!(plan_id, item_key, actor)

      %{
        role: to_string(role),
        item_id: item.id
      }
    end)
  end

  defp quantity_from_event(payload, nil), do: Value.value(payload, "amount")

  defp quantity_from_event(payload, track) do
    quantity_from_target(payload, track.target) || Value.value(payload, "amount")
  end

  defp unit_from_event(payload, nil), do: Value.value(payload, "unit")

  defp unit_from_event(payload, track) do
    Value.value(track.target, "unit") || Value.value(payload, "unit")
  end

  defp quantity_from_target(payload, target) do
    case Value.value(target, "quantity_path") do
      path when is_binary(path) -> PathReader.value(payload, path)
      _other -> nil
    end
  end

  defp event_summary(_event_type, _links, track, quantity, unit)
       when not is_nil(track) do
    track_summary(track, quantity, unit)
  end

  defp event_summary(
         event_type,
         [%{role: role, item_id: item_id} | _links],
         _goal,
         _quantity,
         _unit
       ) do
    "#{event_type.name} for #{role} #{item_id}"
  end

  defp event_summary(event_type, _links, _goal, _quantity, _unit), do: "#{event_type.name} logged"

  defp track_summary(track, quantity, unit)
       when not is_nil(quantity) and not is_nil(unit) do
    case Value.value(track.target, "summary_template") do
      template when is_binary(template) ->
        template
        |> String.replace("%{quantity}", to_string(quantity))
        |> String.replace("%{unit}", to_string(unit))

      _other ->
        "#{quantity} #{unit} for #{track.name}"
    end
  end

  defp track_summary(track, _quantity, _unit), do: "#{track.name} logged"

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

  defp event_datetime(opts) do
    case Keyword.fetch(opts, :effective_at) do
      {:ok, effective_at} -> effective_at
      :error -> Value.default_datetime(Keyword.fetch!(opts, :on))
    end
  end
end
