defmodule Improve.Planning.Diagnostics do
  @moduledoc """
  Plain-English diagnostics for authored plan content.
  """

  @known_schedule_kinds ~w(every_day selected_weekdays times_per_week every_n_days every_n_weeks monthly after_completion custom)
  @supported_schedule_kinds ~w(every_day selected_weekdays times_per_week every_n_days every_n_weeks monthly)
  @keyed_collections ~w(item_types items pools environments event_types session_templates tracks schedules sample_events)
  @quantity_effect_types ~w(add_quantity subtract_quantity set_quantity correction)

  alias Improve.Planning.PlanDraft
  alias Improve.Planning.PathReader

  def validate_plan_draft(draft) do
    schema_required_diagnostics(draft) ++
      duplicate_key_diagnostics(draft) ++
      stable_reference_diagnostics(draft) ++
      missing_pool_diagnostics(draft) ++
      missing_item_type_diagnostics(draft) ++
      duplicate_event_role_diagnostics(draft) ++
      track_target_diagnostics(draft) ++
      effect_rule_diagnostics(draft) ++
      schedule_diagnostics(draft) ++
      event_sample_diagnostics(draft)
  end

  defp schema_required_diagnostics(draft) do
    schema = PlanDraft.schema()

    top_level_required_diagnostics(draft, schema.top_level.required) ++
      collection_required_diagnostics(draft, schema.collections)
  end

  defp top_level_required_diagnostics(draft, required_fields) do
    Enum.flat_map(required_fields, fn field ->
      if blank?(value(draft, field)) do
        [
          missing_required_field_diagnostic(
            "This plan draft is missing a required top-level field.",
            %{field: field},
            path: [Atom.to_string(field)],
            ref: Atom.to_string(field)
          )
        ]
      else
        []
      end
    end)
  end

  defp collection_required_diagnostics(draft, collections) do
    Enum.flat_map(collections, fn {collection, spec} ->
      collection_key = Atom.to_string(collection)

      records =
        draft
        |> list(collection_key, fallback: collection_fallback(collection))
        |> Enum.with_index()

      record_diagnostics =
        Enum.flat_map(records, fn {record, index} ->
          required_record_field_diagnostics(collection_key, record, index, spec.required)
        end)

      child_diagnostics =
        Enum.flat_map(Map.get(spec, :children, %{}), fn {child_collection, child_spec} ->
          child_collection_key = Atom.to_string(child_collection)

          Enum.flat_map(records, fn {record, index} ->
            parent_ref = record_ref(record, index)

            record
            |> list(child_collection_key)
            |> Enum.with_index()
            |> Enum.flat_map(fn {child, child_index} ->
              required_child_field_diagnostics(
                collection_key,
                parent_ref,
                child_collection_key,
                child,
                child_index,
                child_spec.required
              )
            end)
          end)
        end)

      record_diagnostics ++ child_diagnostics
    end)
  end

  defp required_record_field_diagnostics(collection, record, index, required_fields) do
    Enum.flat_map(required_fields, fn field ->
      if blank?(value(record, field)) do
        [
          missing_required_field_diagnostic(
            "This #{human_collection(collection)} entry is missing a required field.",
            %{collection: collection, field: field, record: record_ref(record, index)},
            path: [collection, record_ref(record, index), Atom.to_string(field)],
            ref: Atom.to_string(field)
          )
        ]
      else
        []
      end
    end)
  end

  defp required_child_field_diagnostics(
         collection,
         parent_ref,
         child_collection,
         child,
         child_index,
         required_fields
       ) do
    Enum.flat_map(required_fields, fn field ->
      if blank?(value(child, field)) do
        [
          missing_required_field_diagnostic(
            "This #{human_collection(child_collection)} entry is missing a required field.",
            %{
              collection: collection,
              parent: parent_ref,
              child_collection: child_collection,
              field: field,
              record: record_ref(child, child_index)
            },
            path: [
              collection,
              parent_ref,
              child_collection,
              record_ref(child, child_index),
              Atom.to_string(field)
            ],
            ref: Atom.to_string(field)
          )
        ]
      else
        []
      end
    end)
  end

  def validate_event_type(event_type, opts \\ []) do
    base_path = Keyword.get(opts, :path, ["event_type"])

    roles =
      (value(event_type, "item_link_roles") || %{})
      |> list("roles")
      |> Enum.map(&value(&1, "role"))
      |> MapSet.new()

    (value(event_type, "effect_rules") || %{})
    |> list("rules")
    |> Enum.with_index()
    |> Enum.flat_map(fn {rule, index} ->
      validate_effect_rule(rule, roles, base_path ++ ["effect_rules", index])
    end)
  end

  defp duplicate_key_diagnostics(draft) do
    Enum.flat_map(@keyed_collections, fn collection ->
      draft
      |> list(collection)
      |> Enum.group_by(&value(&1, "key"))
      |> Enum.flat_map(fn
        {nil, _records} ->
          []

        {_key, [_record]} ->
          []

        {key, records} ->
          [
            diagnostic(
              :duplicate_key,
              "This plan defines the same key more than once in #{human_collection(collection)}.",
              %{
                collection: collection,
                key: key,
                count: length(records)
              },
              path: [collection, key],
              ref: key
            )
          ]
      end)
    end)
  end

  defp missing_pool_diagnostics(draft) do
    pool_keys = key_set(list(draft, "pools"))

    draft
    |> session_slots()
    |> Enum.flat_map(fn {template, slot} ->
      pool_key = value(slot, "pool_key") || value(slot, "pool")

      if present?(pool_key) and not MapSet.member?(pool_keys, pool_key) do
        [
          diagnostic(
            :missing_pool,
            "This session slot points at a pool that does not exist.",
            %{
              pool_key: pool_key,
              session_template_key: value(template, "key"),
              slot_key: value(slot, "key")
            },
            path: slot_path(template, slot) ++ ["pool_key"],
            ref: pool_key
          )
        ]
      else
        []
      end
    end)
  end

  defp missing_item_type_diagnostics(draft) do
    item_type_keys = key_set(list(draft, "item_types"))

    draft
    |> list("event_types")
    |> Enum.flat_map(fn event_type ->
      event_type
      |> item_link_roles()
      |> Enum.flat_map(fn role ->
        item_type_key = value(role, "item_type_key")

        if present?(item_type_key) and not MapSet.member?(item_type_keys, item_type_key) do
          [
            diagnostic(
              :missing_item_type,
              "This event item role points at an item type that does not exist.",
              %{
                event_type_key: value(event_type, "key"),
                role: value(role, "role"),
                item_type_key: item_type_key
              },
              path: event_role_path(event_type, role) ++ ["item_type_key"],
              ref: item_type_key
            )
          ]
        else
          []
        end
      end)
    end)
  end

  defp stable_reference_diagnostics(draft) do
    refs = %{
      item_types: key_set(list(draft, "item_types")),
      items: key_set(list(draft, "items")),
      environments: key_set(list(draft, "environments")),
      event_types: key_set(list(draft, "event_types")),
      session_templates: key_set(list(draft, "session_templates")),
      tracks: key_set(list(draft, "tracks"))
    }

    []
    |> missing_refs(list(draft, "items"), :missing_item_type, "item_type_key", refs.item_types)
    |> missing_refs(list(draft, "pools"), :missing_item, "item_keys", refs.items)
    |> missing_refs(list(draft, "environments"), :missing_item, "available_item_keys", refs.items)
    |> missing_refs(
      list(draft, "tracks"),
      :missing_event_type,
      "event_type_key",
      refs.event_types
    )
    |> missing_session_environment_refs(draft, refs)
    |> missing_schedule_owner_refs(draft, refs)
    |> missing_sample_event_refs(draft, refs)
  end

  defp missing_refs(diagnostics, records, code, field, valid_refs) do
    Enum.flat_map(records, fn record ->
      record
      |> list(field)
      |> case do
        [] -> [value(record, field)]
        refs -> refs
      end
      |> Enum.reject(&blank?/1)
      |> Enum.reject(&MapSet.member?(valid_refs, &1))
      |> Enum.map(fn ref ->
        missing_ref_diagnostic(code, record, field, ref)
      end)
    end) ++ diagnostics
  end

  defp missing_session_environment_refs(diagnostics, draft, refs) do
    draft
    |> list("session_templates")
    |> Enum.flat_map(fn template ->
      environment_key = value(template, "environment_key")

      if present?(environment_key) and not MapSet.member?(refs.environments, environment_key) do
        [
          diagnostic(
            :missing_environment,
            "This session template points at an environment that does not exist.",
            %{session_template_key: value(template, "key"), environment_key: environment_key},
            path: ["session_templates", value(template, "key"), "environment_key"],
            ref: environment_key
          )
        ]
      else
        []
      end
    end)
    |> Kernel.++(diagnostics)
  end

  defp missing_schedule_owner_refs(diagnostics, draft, refs) do
    draft
    |> list("schedules")
    |> Enum.flat_map(fn schedule ->
      owner_type = schedule |> value("owner_type") |> normalize_string()
      owner_key = value(schedule, "owner_key")

      cond do
        owner_type == "session_template" and not MapSet.member?(refs.session_templates, owner_key) ->
          [
            diagnostic(
              :missing_schedule_owner,
              "This schedule points at a session template that does not exist.",
              %{
                schedule_key: value(schedule, "key"),
                owner_type: owner_type,
                owner_key: owner_key
              },
              path: schedule_path(schedule) ++ ["owner_key"],
              ref: owner_key
            )
          ]

        owner_type == "track" and not MapSet.member?(refs.tracks, owner_key) ->
          [
            diagnostic(
              :missing_schedule_owner,
              "This schedule points at a track that does not exist.",
              %{
                schedule_key: value(schedule, "key"),
                owner_type: owner_type,
                owner_key: owner_key
              },
              path: schedule_path(schedule) ++ ["owner_key"],
              ref: owner_key
            )
          ]

        owner_type not in ["session_template", "track"] ->
          [
            diagnostic(
              :unsupported_schedule_owner_type,
              "This schedule owner type is not supported.",
              %{schedule_key: value(schedule, "key"), owner_type: owner_type},
              path: schedule_path(schedule) ++ ["owner_type"],
              ref: owner_type
            )
          ]

        true ->
          []
      end
    end)
    |> Kernel.++(diagnostics)
  end

  defp missing_sample_event_refs(diagnostics, draft, refs) do
    draft
    |> list("sample_events", fallback: "events")
    |> Enum.flat_map(fn event ->
      event_type_key = value(event, "event_type_key")
      track_key = value(event, "track_key")

      missing_event_type =
        if present?(event_type_key) and not MapSet.member?(refs.event_types, event_type_key) do
          [
            diagnostic(
              :missing_event_type,
              "This sample event points at an event type that does not exist.",
              %{event_key: event_ref(event), event_type_key: event_type_key},
              path: event_path(event) ++ ["event_type_key"],
              ref: event_type_key
            )
          ]
        else
          []
        end

      missing_track =
        if present?(track_key) and not MapSet.member?(refs.tracks, track_key) do
          [
            diagnostic(
              :missing_track,
              "This sample event points at a track that does not exist.",
              %{event_key: event_ref(event), track_key: track_key},
              path: event_path(event) ++ ["track_key"],
              ref: track_key
            )
          ]
        else
          []
        end

      missing_event_type ++ missing_track
    end)
    |> Kernel.++(diagnostics)
  end

  defp missing_ref_diagnostic(:missing_item_type, record, field, ref) do
    diagnostic(
      :missing_item_type,
      "This item points at an item type that does not exist.",
      %{key: value(record, "key"), field: field, ref: ref},
      path: ["items", value(record, "key"), field],
      ref: ref
    )
  end

  defp missing_ref_diagnostic(:missing_item, record, field, ref) do
    diagnostic(
      :missing_item,
      "This draft points at an item that does not exist.",
      %{key: value(record, "key"), field: field, ref: ref},
      path: [value(record, "key"), field],
      ref: ref
    )
  end

  defp missing_ref_diagnostic(:missing_event_type, record, field, ref) do
    diagnostic(
      :missing_event_type,
      "This track points at an event type that does not exist.",
      %{track_key: value(record, "key"), field: field, ref: ref},
      path: ["tracks", value(record, "key"), field],
      ref: ref
    )
  end

  defp missing_required_field_diagnostic(message, details, opts) do
    diagnostic(:missing_required_field, message, details, opts)
  end

  defp duplicate_event_role_diagnostics(draft) do
    draft
    |> list("event_types")
    |> Enum.flat_map(fn event_type ->
      event_type
      |> item_link_roles()
      |> Enum.group_by(&value(&1, "role"))
      |> Enum.flat_map(fn
        {role, roles} when not is_nil(role) and length(roles) > 1 ->
          [
            diagnostic(
              :duplicate_item_link_role,
              "This event type defines the same item link role more than once.",
              %{event_type_key: value(event_type, "key"), role: role, count: length(roles)},
              path: ["event_types", value(event_type, "key"), "item_link_roles", role],
              ref: role
            )
          ]

        _other ->
          []
      end)
    end)
  end

  defp track_target_diagnostics(draft) do
    draft
    |> list("tracks")
    |> Enum.flat_map(fn track ->
      target = value(track, "target") || %{}
      quantity = value(target, "quantity")
      unit = value(target, "unit")

      cond do
        present?(quantity) and blank?(unit) ->
          [
            diagnostic(
              :track_target_unit_missing,
              "This track target has a quantity but no unit.",
              %{track_key: value(track, "key"), quantity: quantity},
              path: ["tracks", value(track, "key"), "target", "unit"],
              ref: value(track, "key")
            )
          ]

        present?(unit) and blank?(quantity) ->
          [
            diagnostic(
              :track_target_quantity_missing,
              "This track target has a unit but no quantity.",
              %{track_key: value(track, "key"), unit: unit},
              path: ["tracks", value(track, "key"), "target", "quantity"],
              ref: value(track, "key")
            )
          ]

        true ->
          []
      end
    end)
  end

  defp effect_rule_diagnostics(draft) do
    draft
    |> list("event_types")
    |> Enum.flat_map(fn event_type ->
      validate_event_type(event_type, path: ["event_types", value(event_type, "key")])
    end)
  end

  defp schedule_diagnostics(draft) do
    draft
    |> list("schedules")
    |> Enum.flat_map(fn schedule ->
      kind = schedule_kind(schedule)

      cond do
        kind not in @known_schedule_kinds ->
          [
            diagnostic(
              :invalid_schedule_kind,
              "This schedule uses a kind that Improve does not recognize.",
              %{kind: kind},
              path: schedule_path(schedule) ++ ["kind"],
              ref: kind
            )
          ]

        kind not in @supported_schedule_kinds ->
          [
            diagnostic(
              :unsupported_schedule_rule,
              "This schedule kind is recognized, but the planner does not support it yet.",
              %{kind: kind},
              path: schedule_path(schedule) ++ ["kind"],
              ref: kind
            )
          ]

        kind == "times_per_week" and
          not is_list(value(value(schedule, "rules") || %{}, "allowed_weekdays")) and
            present?(value(value(schedule, "rules") || %{}, "allowed_weekdays")) ->
          [
            diagnostic(
              :unsupported_schedule_rule_shape,
              "This times-per-week schedule has allowed_weekdays, but it is not a list.",
              %{
                kind: kind,
                allowed_weekdays: value(value(schedule, "rules") || %{}, "allowed_weekdays")
              },
              path: schedule_path(schedule) ++ ["rules", "allowed_weekdays"],
              ref: value(schedule, "key")
            )
          ]

        true ->
          []
      end
    end)
  end

  defp event_sample_diagnostics(draft) do
    event_types_by_key = Map.new(list(draft, "event_types"), &{value(&1, "key"), &1})

    draft
    |> list("sample_events", fallback: "events")
    |> Enum.flat_map(fn event ->
      event_type = Map.get(event_types_by_key, value(event, "event_type_key"))

      if event_type do
        missing_required_link_diagnostics(event_type, event) ++
          incompatible_effect_quantity_diagnostics(event_type, event)
      else
        []
      end
    end)
  end

  defp missing_required_link_diagnostics(event_type, event) do
    links = value(event, "item_links") || %{}

    event_type
    |> item_link_roles()
    |> Enum.flat_map(fn role ->
      role_key = value(role, "role")

      if truthy?(value(role, "required")) and blank?(value(links, role_key)) do
        [
          diagnostic(
            :missing_required_item_link_role,
            missing_required_link_message(role_key),
            %{
              event_key: event_ref(event),
              event_type_key: value(event_type, "key"),
              role: role_key
            },
            path: event_path(event) ++ ["item_links", role_key],
            ref: role_key
          )
        ]
      else
        []
      end
    end)
  end

  defp incompatible_effect_quantity_diagnostics(event_type, event) do
    roles =
      event_type
      |> item_link_roles()
      |> Enum.map(&value(&1, "role"))
      |> MapSet.new()

    event_type
    |> effect_rules()
    |> Enum.flat_map(fn rule ->
      role = value(rule, "role")
      effect_type = value(rule, "effect_type")
      quantity_path = value(rule, "quantity_path")
      quantity = path_value(value(event, "payload") || %{}, quantity_path)

      if MapSet.member?(roles, role) and effect_type in @quantity_effect_types and
           not decimal_like?(quantity) do
        [
          diagnostic(
            :effect_rule_quantity_incompatible,
            "This event quantity cannot be used by its item effect rule.",
            %{
              event_key: event_ref(event),
              event_type_key: value(event_type, "key"),
              quantity_path: quantity_path,
              quantity: quantity
            },
            path: event_path(event) ++ payload_path(quantity_path),
            ref: quantity_path
          )
        ]
      else
        []
      end
    end)
  end

  defp validate_effect_rule(rule, roles, path) do
    role = value(rule, "role")

    cond do
      is_nil(role) ->
        [
          diagnostic(
            :effect_rule_missing_role,
            "Effect rule is missing an item link role.",
            %{rule: rule},
            path: path,
            ref: nil
          )
        ]

      not MapSet.member?(roles, role) ->
        [
          diagnostic(
            :effect_rule_unknown_role,
            "Effect rule refers to an item link role that is not declared.",
            %{role: role},
            path: path ++ ["role"],
            ref: role
          )
        ]

      true ->
        []
    end
  end

  defp session_slots(draft) do
    nested_slots =
      draft
      |> list("session_templates")
      |> Enum.flat_map(fn template ->
        template
        |> list("slots")
        |> Enum.map(&{template, &1})
      end)

    top_level_slots = Enum.map(list(draft, "session_slots"), &{%{}, &1})

    nested_slots ++ top_level_slots
  end

  defp item_link_roles(event_type), do: list(value(event_type, "item_link_roles") || %{}, "roles")
  defp effect_rules(event_type), do: list(value(event_type, "effect_rules") || %{}, "rules")

  defp key_set(records) do
    records
    |> Enum.map(&value(&1, "key"))
    |> Enum.reject(&blank?/1)
    |> MapSet.new()
  end

  defp slot_path(template, slot) do
    if present?(value(template, "key")) do
      ["session_templates", value(template, "key"), "slots", value(slot, "key")]
    else
      ["session_slots", value(slot, "key")]
    end
  end

  defp event_role_path(event_type, role) do
    ["event_types", value(event_type, "key"), "item_link_roles", value(role, "role")]
  end

  defp schedule_path(schedule) do
    [
      "schedules",
      value(schedule, "key") || value(schedule, "owner_key") || value(schedule, "owner_id")
    ]
  end

  defp event_path(event), do: ["events", event_ref(event)]

  defp event_ref(event),
    do: value(event, "key") || value(event, "id") || value(event, "event_type_key")

  defp record_ref(record, index), do: value(record, "key") || Integer.to_string(index)

  defp collection_fallback(:sample_events), do: "events"
  defp collection_fallback(_collection), do: nil

  defp payload_path("payload." <> path), do: ["payload" | String.split(path, ".")]
  defp payload_path(path) when is_binary(path), do: ["payload", path]
  defp payload_path(_path), do: ["payload"]

  defp path_value(payload, path), do: PathReader.value(payload, path)

  defp schedule_kind(schedule), do: schedule |> value("kind") |> normalize_string()

  defp normalize_string(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_string(value) when is_binary(value), do: value
  defp normalize_string(value), do: value

  defp list(source, key, opts \\ []) do
    source
    |> value(key)
    |> case do
      nil -> value(source, Keyword.get(opts, :fallback))
      found -> found
    end
    |> normalize_list()
  end

  defp normalize_list(nil), do: []
  defp normalize_list(list) when is_list(list), do: list
  defp normalize_list(map) when is_map(map), do: Map.values(map)
  defp normalize_list(_value), do: []

  defp value(nil, _key), do: nil

  defp value(source, key) when is_map(source) and is_atom(key) do
    Map.get(source, key) || Map.get(source, Atom.to_string(key))
  end

  defp value(source, key) when is_map(source) and is_binary(key) do
    Map.get(source, key) || Map.get(source, existing_atom(key))
  end

  defp value(_source, _key), do: nil

  defp decimal_like?(value) when is_integer(value), do: true
  defp decimal_like?(%Decimal{}), do: true

  defp decimal_like?(value) when is_float(value), do: value == value

  defp decimal_like?(value) when is_binary(value) do
    Decimal.new(value)
    true
  rescue
    Decimal.Error -> false
  end

  defp decimal_like?(_value), do: false

  defp missing_required_link_message(_role) do
    "This event is missing a required item link role."
  end

  defp human_collection(collection), do: String.replace(collection, "_", " ")

  defp present?(value), do: not blank?(value)
  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(_value), do: false

  defp truthy?(true), do: true
  defp truthy?("true"), do: true
  defp truthy?(1), do: true
  defp truthy?(_value), do: false

  defp existing_atom(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end

  defp diagnostic(code, message, details, opts) do
    %{
      severity: Keyword.get(opts, :severity, :error),
      code: code,
      message: message,
      path: Keyword.get(opts, :path, []),
      ref: Keyword.get(opts, :ref),
      details: details
    }
  end
end
