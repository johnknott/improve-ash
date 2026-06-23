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

  defp direct_goal!(plan_id, key, actor) do
    actor
    |> direct_goals(plan_id)
    |> Enum.find(&(&1.key == key))
    |> case do
      nil -> raise ArgumentError, "No direct goal #{inspect(key)} exists in this plan."
      direct_goal -> direct_goal
    end
  end

  defp event_types(actor, plan_id) do
    Plans.list_event_types!(actor: actor, query: [filter: [plan_id: plan_id]])
  end

  defp direct_goals(actor, plan_id) do
    Plans.list_direct_goals!(actor: actor, query: [filter: [plan_id: plan_id]])
  end

  defp default_datetime(date) do
    DateTime.new!(date, ~T[20:00:00], "Etc/UTC")
  end

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
