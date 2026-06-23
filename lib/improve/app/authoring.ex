defmodule Improve.App.Authoring do
  @moduledoc """
  Product-facing authoring operations for plans and plan definitions.
  """

  alias Improve.App.Lookup
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

  def add_exercise!(plan, name, opts) do
    actor = actor!(opts)
    ensure_item_type!(plan, "exercise", "Exercise", actor)

    add_item!(
      plan,
      name,
      opts
      |> Keyword.put(:actor, actor)
      |> Keyword.put(:type, "exercise")
      |> Keyword.put_new(:key, Value.key_from(name))
      |> Keyword.put_new(:facts, %{})
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

  def add_direct_goal!(plan, name, opts) do
    actor = actor!(opts)
    event_type = Lookup.event_type!(plan, Keyword.fetch!(opts, :event), actor)
    schedule = Keyword.fetch!(opts, :schedule)

    direct_goal =
      Plans.create_direct_goal!(
        %{
          plan_id: plan.id,
          event_type_id: event_type.id,
          key: Keyword.get(opts, :key, Value.key_from(name)),
          name: name,
          description: Keyword.get(opts, :description),
          target: Value.stringify_keys(Keyword.get(opts, :target, %{})),
          completion_policy: Value.stringify_keys(Keyword.get(opts, :completion_policy, %{})),
          missed_policy: Value.stringify_keys(Keyword.get(opts, :missed_policy, %{}))
        },
        actor: actor
      )

    create_schedule!(plan, :direct_goal, direct_goal, schedule, actor)
    direct_goal
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

  defp ensure_item_type!(plan, key, name, actor) do
    case Enum.find(Lookup.item_types(actor, plan), &(&1.key == key)) do
      nil -> add_item_type!(plan, name, key: key, actor: actor)
      item_type -> item_type
    end
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
