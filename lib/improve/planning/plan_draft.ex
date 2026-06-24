defmodule Improve.Planning.PlanDraft do
  @moduledoc """
  Versioned portable authored-plan draft shape.

  Drafts use stable keys instead of database IDs so plans can be exported,
  edited, imported, compared in tests, or passed through authoring tools without
  leaking internal persistence details.
  """

  @current_version 1

  @empty_collections [
    :item_types,
    :items,
    :pools,
    :environments,
    :event_types,
    :session_templates,
    :tracks,
    :schedules,
    :sample_events
  ]

  @schema %{
    schema: "improve.plan_draft",
    version: @current_version,
    stable_identity: [:key, :source],
    top_level: %{
      required: [:schema, :version, :key, :name],
      optional: [:intention, :starts_on, :ends_on, :status, :source, :display_hints]
    },
    collections: %{
      item_types: %{
        required: [:key, :name],
        optional: [:description, :facts_schema, :display_hints]
      },
      items: %{
        required: [:key, :name, :item_type_key],
        optional: [:facts, :stateful, :display_hints],
        references: %{item_type_key: :item_types}
      },
      pools: %{
        required: [:key, :name],
        optional: [:description, :item_keys, :rules, :display_hints],
        references: %{item_keys: :items}
      },
      environments: %{
        required: [:key, :name],
        optional: [:description, :available_item_keys, :rules, :display_hints],
        references: %{available_item_keys: :items}
      },
      event_types: %{
        required: [:key, :name],
        optional: [:description, :payload_schema, :item_link_roles, :effect_rules, :display_hints],
        nested_references: %{
          item_link_roles: %{item_type_key: :item_types},
          effect_rules: %{role: :event_type_item_link_roles}
        }
      },
      session_templates: %{
        required: [:key, :name],
        optional: [
          :description,
          :environment_key,
          :completion_policy,
          :missed_policy,
          :display_hints,
          :slots
        ],
        references: %{environment_key: :environments},
        children: %{
          slots: %{
            required: [:key, :name, :pool_key],
            optional: [:count, :optional, :rules, :position],
            references: %{pool_key: :pools}
          }
        }
      },
      tracks: %{
        required: [:key, :name, :event_type_key],
        optional: [:description, :target, :completion_policy, :missed_policy, :display_hints],
        references: %{event_type_key: :event_types},
        policy_fields: [:target, :completion_policy, :missed_policy]
      },
      schedules: %{
        required: [:key, :owner_type, :owner_key, :kind, :starts_on],
        optional: [:ends_on, :rules, :display_hints],
        references: %{
          owner_key: [:session_templates, :tracks]
        },
        supported_owner_types: [:session_template, :track],
        supported_kinds: [:every_day, :selected_weekdays, :every_n_days, :times_per_week]
      },
      sample_events: %{
        required: [:key, :event_type_key, :effective_at],
        optional: [
          :recorded_at,
          :summary,
          :quantity,
          :unit,
          :payload,
          :note,
          :item_links,
          :track_key
        ],
        references: %{event_type_key: :event_types, track_key: :tracks}
      }
    }
  }

  def current_version, do: @current_version

  def schema, do: @schema

  def collection_names, do: @empty_collections

  def empty(attrs \\ %{}) do
    attrs
    |> atomize_known_keys()
    |> Map.merge(
      %{
        schema: "improve.plan_draft",
        version: @current_version,
        item_types: [],
        items: [],
        pools: [],
        environments: [],
        event_types: [],
        session_templates: [],
        tracks: [],
        schedules: [],
        sample_events: []
      },
      fn _key, provided, _default -> provided end
    )
  end

  def normalize(draft) when is_map(draft) do
    draft
    |> atomize_known_keys()
    |> Map.update(:version, @current_version, &normalize_version/1)
    |> Map.put_new(:schema, "improve.plan_draft")
    |> then(fn draft ->
      Enum.reduce(@empty_collections, draft, fn collection, draft ->
        Map.update(draft, collection, [], &normalize_collection/1)
      end)
    end)
  end

  def normalize(_draft), do: empty()

  def stable_reference_fields do
    @schema.collections
    |> Enum.flat_map(fn {collection, spec} ->
      references =
        spec
        |> Map.get(:references, %{})
        |> Map.keys()

      Enum.map(references, &{collection, &1})
    end)
  end

  defp atomize_known_keys(map) do
    Map.new(map, fn {key, value} ->
      {known_key(key), value}
    end)
  end

  defp known_key(key) when is_atom(key), do: key

  defp known_key(key) when is_binary(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> key
  end

  defp normalize_version(version) when is_integer(version), do: version

  defp normalize_version(version) when is_binary(version) do
    case Integer.parse(version) do
      {version, ""} -> version
      _other -> @current_version
    end
  end

  defp normalize_version(_version), do: @current_version

  defp normalize_collection(collection) when is_list(collection), do: collection
  defp normalize_collection(collection) when is_map(collection), do: Map.values(collection)
  defp normalize_collection(_collection), do: []
end
