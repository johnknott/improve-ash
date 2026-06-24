defmodule Improve.Planning.PlanDraftExporter do
  @moduledoc """
  Exports persisted plan definitions to portable stable-key drafts.
  """

  alias Improve.Planning.PlanDraft
  alias Improve.Plans

  def export(plan_or_id, opts) do
    actor = Keyword.fetch!(opts, :actor)

    with {:ok, plan} <- fetch_plan(plan_or_id, actor),
         {:ok, definitions} <- fetch_definitions(plan, actor) do
      {:ok, draft(plan, definitions)}
    end
  end

  def export!(plan_or_id, opts) do
    case export(plan_or_id, opts) do
      {:ok, draft} -> draft
      {:error, error} -> raise error
    end
  end

  defp fetch_plan(%{id: id}, actor), do: Plans.get_plan(id, actor: actor)
  defp fetch_plan(id, actor), do: Plans.get_plan(id, actor: actor)

  defp fetch_definitions(plan, actor) do
    plan_filter = [filter: [plan_id: plan.id]]

    with {:ok, item_types} <- Plans.list_item_types(actor: actor, query: plan_filter),
         {:ok, items} <- Plans.list_items(actor: actor, query: plan_filter),
         {:ok, pools} <- Plans.list_pools(actor: actor, query: plan_filter),
         {:ok, pool_memberships} <- Plans.list_pool_memberships(actor: actor, query: plan_filter),
         {:ok, environments} <- Plans.list_environments(actor: actor, query: plan_filter),
         {:ok, event_types} <- Plans.list_event_types(actor: actor, query: plan_filter),
         {:ok, session_templates} <-
           Plans.list_session_templates(actor: actor, query: plan_filter),
         {:ok, session_slots} <- Plans.list_session_slots(actor: actor, query: plan_filter),
         {:ok, tracks} <- Plans.list_tracks(actor: actor, query: plan_filter),
         {:ok, schedules} <- Plans.list_schedules(actor: actor, query: plan_filter) do
      {:ok,
       %{
         item_types: item_types,
         items: items,
         pools: pools,
         pool_memberships: pool_memberships,
         environments: environments,
         event_types: event_types,
         session_templates: session_templates,
         session_slots: session_slots,
         tracks: tracks,
         schedules: schedules
       }}
    end
  end

  defp draft(plan, definitions) do
    indexes = indexes(definitions)

    PlanDraft.empty(%{
      key: plan.source_key || plan.name |> key_from_name(),
      name: plan.name,
      intention: plan.intention,
      starts_on: date(plan.starts_on),
      ends_on: date(plan.ends_on),
      status: atom_string(plan.status),
      source: %{
        "kind" => atom_string(plan.source_kind),
        "key" => plan.source_key
      },
      item_types: Enum.map(sort_keyed(definitions.item_types), &item_type_draft/1),
      items: Enum.map(sort_keyed(definitions.items), &item_draft(&1, indexes)),
      pools: Enum.map(sort_keyed(definitions.pools), &pool_draft(&1, definitions, indexes)),
      environments:
        Enum.map(sort_keyed(definitions.environments), &environment_draft(&1, indexes)),
      event_types: Enum.map(sort_keyed(definitions.event_types), &event_type_draft/1),
      session_templates:
        Enum.map(
          sort_keyed(definitions.session_templates),
          &session_template_draft(&1, definitions, indexes)
        ),
      tracks: Enum.map(sort_keyed(definitions.tracks), &track_draft(&1, indexes)),
      schedules:
        Enum.map(sort_schedules(definitions.schedules, indexes), &schedule_draft(&1, indexes)),
      sample_events: []
    })
  end

  defp indexes(definitions) do
    %{
      item_types: id_to_key(definitions.item_types),
      items: id_to_key(definitions.items),
      pools: id_to_key(definitions.pools),
      environments: id_to_key(definitions.environments),
      event_types: id_to_key(definitions.event_types),
      session_templates: id_to_key(definitions.session_templates),
      tracks: id_to_key(definitions.tracks)
    }
  end

  defp id_to_key(records), do: Map.new(records, &{&1.id, &1.key})

  defp item_type_draft(item_type) do
    compact(%{
      key: item_type.key,
      name: item_type.name,
      description: item_type.description,
      facts_schema: item_type.facts_schema,
      display_hints: item_type.display_hints
    })
  end

  defp item_draft(item, indexes) do
    compact(%{
      key: item.key,
      name: item.name,
      item_type_key: Map.fetch!(indexes.item_types, item.item_type_id),
      facts: item.facts,
      stateful: item.stateful
    })
  end

  defp pool_draft(pool, definitions, indexes) do
    item_keys =
      definitions.pool_memberships
      |> Enum.filter(&(&1.pool_id == pool.id))
      |> Enum.map(&Map.fetch!(indexes.items, &1.item_id))
      |> Enum.sort()

    compact(%{
      key: pool.key,
      name: pool.name,
      description: pool.description,
      item_keys: item_keys
    })
  end

  defp environment_draft(environment, indexes) do
    available_item_keys =
      environment.available_item_ids
      |> Enum.map(&Map.fetch!(indexes.items, &1))
      |> Enum.sort()

    compact(%{
      key: environment.key,
      name: environment.name,
      description: environment.description,
      available_item_keys: available_item_keys
    })
  end

  defp event_type_draft(event_type) do
    compact(%{
      key: event_type.key,
      name: event_type.name,
      description: event_type.description,
      payload_schema: event_type.payload_schema,
      item_link_roles: event_type.item_link_roles,
      effect_rules: event_type.effect_rules
    })
  end

  defp session_template_draft(template, definitions, indexes) do
    slots =
      definitions.session_slots
      |> Enum.filter(&(&1.session_template_id == template.id))
      |> Enum.sort_by(&{&1.position, &1.key})
      |> Enum.map(&session_slot_draft(&1, indexes))

    compact(%{
      key: template.key,
      name: template.name,
      description: template.description,
      environment_key: key(indexes.environments, template.environment_id),
      completion_policy: template.completion_policy,
      missed_policy: template.missed_policy,
      slots: slots
    })
  end

  defp session_slot_draft(slot, indexes) do
    compact(%{
      key: slot.key,
      name: slot.name,
      pool_key: Map.fetch!(indexes.pools, slot.pool_id),
      count: slot.count,
      optional: slot.optional,
      rules: slot.rules,
      position: slot.position
    })
  end

  defp track_draft(track, indexes) do
    compact(%{
      key: track.key,
      name: track.name,
      description: track.description,
      event_type_key: Map.fetch!(indexes.event_types, track.event_type_id),
      target: track.target,
      completion_policy: track.completion_policy,
      missed_policy: track.missed_policy
    })
  end

  defp schedule_draft(schedule, indexes) do
    compact(%{
      key: schedule_key(schedule, indexes),
      owner_type: atom_string(schedule.owner_type),
      owner_key: owner_key(schedule, indexes),
      kind: atom_string(schedule.kind),
      starts_on: date(schedule.starts_on),
      ends_on: date(schedule.ends_on),
      rules: schedule.rules
    })
  end

  defp schedule_key(schedule, indexes) do
    [owner_key(schedule, indexes), atom_string(schedule.kind), date(schedule.starts_on)]
    |> Enum.reject(&blank?/1)
    |> Enum.join("__")
  end

  defp owner_key(%{owner_type: :session_template, owner_id: owner_id}, indexes) do
    Map.fetch!(indexes.session_templates, owner_id)
  end

  defp owner_key(%{owner_type: :track, owner_id: owner_id}, indexes) do
    Map.fetch!(indexes.tracks, owner_id)
  end

  defp sort_keyed(records), do: Enum.sort_by(records, & &1.key)

  defp sort_schedules(schedules, indexes) do
    Enum.sort_by(schedules, &schedule_key(&1, indexes))
  end

  defp key(_map, nil), do: nil
  defp key(map, id), do: Map.fetch!(map, id)

  defp date(nil), do: nil
  defp date(%Date{} = date), do: Date.to_iso8601(date)

  defp atom_string(nil), do: nil
  defp atom_string(value) when is_atom(value), do: Atom.to_string(value)
  defp atom_string(value), do: value

  defp key_from_name(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "_")
    |> String.trim("_")
  end

  defp compact(map) do
    Map.reject(map, fn
      {_key, nil} -> true
      {_key, ""} -> true
      {_key, value} when is_map(value) and map_size(value) == 0 -> true
      {_key, []} -> true
      {_key, false} -> true
      {_key, 0} -> false
      {_key, _value} -> false
    end)
  end

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(_value), do: false
end
