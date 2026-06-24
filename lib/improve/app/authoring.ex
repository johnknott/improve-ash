defmodule Improve.App.Authoring do
  @moduledoc """
  Product-facing authoring operations for plans and plan definitions.
  """

  alias Improve.App.Lookup
  alias Improve.App.Target
  alias Improve.App.Value
  alias Improve.Plans

  def create_plan!(name, opts) do
    Plans.create_plan!(
      %{
        name: name,
        intention: Keyword.fetch!(opts, :intention),
        starts_on: Keyword.fetch!(opts, :from),
        ends_on: Keyword.fetch!(opts, :until),
        status: Keyword.get(opts, :status, :active),
        source_kind: Keyword.get(opts, :source_kind, :manual),
        source_key: Keyword.get(opts, :source_key)
      },
      actor: actor!(opts)
    )
  end

  def add_event_type!(plan, name, opts) do
    Plans.create_event_type!(
      %{
        plan_id: plan.id,
        key: Keyword.get(opts, :key, Value.key_from(name)),
        name: name,
        description: Keyword.get(opts, :description),
        payload_schema: Value.stringify_keys(Keyword.get(opts, :payload, %{})),
        item_link_roles: item_link_roles(Keyword.get(opts, :required_links, [])),
        effect_rules: effect_rules(Keyword.get(opts, :effects, []))
      },
      actor: actor!(opts)
    )
  end

  def add_item_type!(plan, name, opts) do
    Plans.create_item_type!(
      %{
        plan_id: plan.id,
        key: Keyword.get(opts, :key, Value.key_from(name)),
        name: name,
        description: Keyword.get(opts, :description),
        facts_schema: Value.stringify_keys(Keyword.get(opts, :facts_schema, %{})),
        display_hints: Value.stringify_keys(Keyword.get(opts, :display_hints, %{}))
      },
      actor: actor!(opts)
    )
  end

  def add_item!(plan, name, opts) do
    actor = actor!(opts)
    item_type = Lookup.item_type!(plan, Keyword.fetch!(opts, :type), actor)

    Plans.create_item!(
      %{
        plan_id: plan.id,
        item_type_id: item_type.id,
        key: Keyword.get(opts, :key, Value.key_from(name)),
        name: name,
        stateful: Keyword.get(opts, :stateful, false),
        facts: Value.stringify_keys(Keyword.get(opts, :facts, %{}))
      },
      actor: actor
    )
  end

  def add_pool!(plan, name, opts) do
    actor = actor!(opts)

    pool =
      Plans.create_pool!(
        %{
          plan_id: plan.id,
          key: Keyword.get(opts, :key, Value.key_from(name)),
          name: name,
          description: Keyword.get(opts, :description)
        },
        actor: actor
      )

    opts
    |> Keyword.get(:items, [])
    |> Enum.each(fn item_key ->
      item = Lookup.item!(plan, item_key, actor)

      Plans.create_pool_membership!(
        %{plan_id: plan.id, pool_id: pool.id, item_id: item.id},
        actor: actor
      )
    end)

    pool
  end

  def add_track!(plan, name, opts) do
    actor = actor!(opts)
    schedule = Keyword.fetch!(opts, :schedule)
    key = Keyword.get(opts, :key, Value.key_from(name))
    records = Keyword.get(opts, :records)
    target = Target.apply_records(Keyword.get(opts, :target, %{}), records)
    event_type = track_event_type!(plan, name, key, target, records, opts, actor)

    track =
      Plans.create_track!(
        %{
          plan_id: plan.id,
          event_type_id: event_type.id,
          key: key,
          name: name,
          description: Keyword.get(opts, :description),
          target: Value.stringify_keys(target),
          completion_policy: Value.stringify_keys(Keyword.get(opts, :completion_policy, %{})),
          missed_policy: Value.stringify_keys(Keyword.get(opts, :missed_policy, %{}))
        },
        actor: actor
      )

    create_schedule!(plan, :track, track, schedule, actor)
    track
  end

  defp track_event_type!(plan, name, key, target, records, opts, actor) do
    if event_key = Keyword.get(opts, :event) do
      Lookup.event_type!(plan, event_key, actor)
    else
      event_key = Keyword.get(opts, :event_key, "#{key}_logged")

      case Enum.find(Lookup.event_types(actor, plan), &(&1.key == event_key)) do
        nil ->
          add_event_type!(plan, Keyword.get(opts, :event_name, "#{name} logged"),
            actor: actor,
            key: event_key,
            payload: inferred_payload_schema(target, records)
          )

        event_type ->
          event_type
      end
    end
  end

  def add_session!(plan, name, opts) do
    actor = actor!(opts)
    schedule = Keyword.fetch!(opts, :schedule)
    defaults = Keyword.get(opts, :defaults, %{})

    session_template =
      Plans.create_session_template!(
        %{
          plan_id: plan.id,
          key: Keyword.get(opts, :key, Value.key_from(name)),
          name: name,
          description: Keyword.get(opts, :description),
          completion_policy: Value.stringify_keys(Keyword.get(opts, :completion_policy, %{})),
          missed_policy: Value.stringify_keys(Keyword.get(opts, :missed_policy, %{}))
        },
        actor: actor
      )

    opts
    |> Keyword.fetch!(:slots)
    |> Enum.with_index(1)
    |> Enum.each(fn {slot, position} ->
      pool = Lookup.pool!(plan, Map.fetch!(slot, :from), actor)

      Plans.create_session_slot!(
        %{
          plan_id: plan.id,
          session_template_id: session_template.id,
          key: Map.get(slot, :key, Map.fetch!(slot, :from)),
          name: Map.get(slot, :name, "#{pool.name} slot"),
          pool_id: pool.id,
          count: Map.fetch!(slot, :count),
          optional: Map.get(slot, :optional, false),
          rules: slot_rules(slot, defaults),
          position: position
        },
        actor: actor
      )
    end)

    create_schedule!(plan, :session_template, session_template, schedule, actor)
    session_template
  end

  defp create_schedule!(plan, owner_type, owner, schedule, actor) do
    Plans.create_schedule!(
      %{
        plan_id: plan.id,
        owner_type: owner_type,
        owner_id: owner.id,
        kind: Map.fetch!(schedule, :kind),
        rules: Map.get(schedule, :rules, %{}),
        starts_on: plan.starts_on,
        ends_on: plan.ends_on
      },
      actor: actor
    )
  end

  defp inferred_payload_schema(_target, %{type: type} = records)
       when type in [:number, :amount] do
    field = Map.fetch!(records, :field)

    %{
      required: [field],
      properties: %{
        field => %{type: "number"},
        note: %{type: "string"}
      }
    }
  end

  defp inferred_payload_schema(_target, %{type: :fields, fields: fields}) do
    %{
      required: fields,
      properties: Map.new(fields, &{&1, %{type: "string"}})
    }
  end

  defp inferred_payload_schema(%{type: :checklist}, _records) do
    %{
      required: ["checked_items"],
      properties: %{
        checked_items: %{type: "array", items: %{type: "string"}},
        note: %{type: "string"}
      }
    }
  end

  defp inferred_payload_schema(%{type: type} = target, _records)
       when type in [:fixed, :metric, :period_total, :progression] do
    unit = Map.get(target, :unit, "amount")
    inferred_payload_schema(target, Target.number(unit))
  end

  defp inferred_payload_schema(_target, _records) do
    raise ArgumentError,
          "A track without an explicit event needs records metadata, such as records: number(\"pages\")."
  end

  defp slot_rules(slot, defaults) do
    slot
    |> Map.get(:rules, %{})
    |> Value.stringify_keys()
    |> Map.merge(default_rules(defaults))
  end

  defp default_rules(defaults) do
    defaults = Value.stringify_keys(defaults || %{})

    %{}
    |> Value.maybe_put("default_event", Map.get(defaults, "event"))
    |> Value.maybe_put("default_payload", Map.get(defaults, "payload"))
    |> Value.maybe_put("default_role", Map.get(defaults, "role"))
  end

  defp item_link_roles([]), do: %{}

  defp item_link_roles(roles) do
    %{
      "roles" =>
        Enum.map(roles, fn role ->
          %{"role" => to_string(role), "required" => true}
        end)
    }
  end

  defp effect_rules([]), do: %{}
  defp effect_rules(rules), do: %{"rules" => Enum.map(rules, &Value.stringify_keys/1)}

  defp actor!(opts), do: Keyword.fetch!(opts, :actor)
end
