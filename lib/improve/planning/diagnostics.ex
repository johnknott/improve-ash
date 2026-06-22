defmodule Improve.Planning.Diagnostics do
  @moduledoc """
  Plain-English diagnostics for authored plan content.
  """

  @known_schedule_kinds ~w(every_day selected_weekdays times_per_week every_n_days after_completion custom)
  @supported_schedule_kinds ~w(every_day selected_weekdays times_per_week)
  @keyed_collections ~w(item_types items pools environments event_types session_templates direct_goals schedules sample_events)
  @quantity_effect_types ~w(add_quantity subtract_quantity set_quantity correction)

  def validate_plan_draft(draft) do
    duplicate_key_diagnostics(draft) ++
      missing_pool_diagnostics(draft) ++
      missing_item_type_diagnostics(draft) ++
      effect_rule_diagnostics(draft) ++
      schedule_diagnostics(draft) ++
      event_sample_diagnostics(draft)
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
              "This schedule kind is recognized, but the POC planner does not support it yet.",
              %{kind: kind},
              path: schedule_path(schedule) ++ ["kind"],
              ref: kind
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
            "This dose event quantity cannot be used by its item effect rule.",
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

  defp payload_path("payload." <> path), do: ["payload" | String.split(path, ".")]
  defp payload_path(path) when is_binary(path), do: ["payload", path]
  defp payload_path(_path), do: ["payload"]

  defp path_value(payload, "payload." <> path), do: get_in_path(payload, String.split(path, "."))

  defp path_value(payload, path) when is_binary(path),
    do: get_in_path(payload, String.split(path, "."))

  defp path_value(_payload, _path), do: nil

  defp get_in_path(source, keys) do
    Enum.reduce_while(keys, source, fn key, current ->
      case value(current, key) do
        nil -> {:halt, nil}
        next -> {:cont, next}
      end
    end)
  end

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

  defp missing_required_link_message("source_vial") do
    "This dose event is missing the required source vial link."
  end

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
