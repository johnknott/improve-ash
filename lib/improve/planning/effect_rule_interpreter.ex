defmodule Improve.Planning.EffectRuleInterpreter do
  @moduledoc """
  Interprets authored event effect rules into item effect specs.

  This module is deliberately pure: it does not read the database, inspect the
  clock, create journal records, or authorize anything. Callers pass explicit
  item links, payload data, and rule data, then persist returned effect specs.
  """

  @effect_types %{
    "add_quantity" => :add_quantity,
    "subtract_quantity" => :subtract_quantity,
    "set_quantity" => :set_quantity,
    "correction" => :correction
  }

  alias Improve.Planning.PathReader

  def interpret(input) do
    rules = Map.get(input, :rules, [])
    item_links = Map.get(input, :item_links, [])
    payload = Map.get(input, :payload, %{})

    {effects, diagnostics} =
      rules
      |> Enum.flat_map_reduce([], &interpret_rule(&1, item_links, payload, &2))

    %{effects: effects, diagnostics: diagnostics}
  end

  defp interpret_rule(rule, item_links, payload, diagnostics) do
    role = Map.get(rule, "role")
    links = Enum.filter(item_links, &(link_role(&1) == role))

    cond do
      is_nil(role) or role == "" ->
        {[], diagnostics ++ ["Effect rule is missing a role."]}

      links == [] ->
        {[], diagnostics ++ ["No item link found for effect role #{role}."]}

      true ->
        case effect_spec(rule, payload, role) do
          {:ok, spec} ->
            {Enum.map(links, &Map.put(spec, :item_id, link_item_id(&1))), diagnostics}

          {:error, diagnostic} ->
            {[], diagnostics ++ [diagnostic]}
        end
    end
  end

  defp effect_spec(rule, payload, role) do
    with {:ok, effect_type} <- effect_type(Map.get(rule, "effect_type"), role),
         {:ok, quantity} <- path_value(payload, Map.get(rule, "quantity_path"), role, "quantity"),
         {:ok, unit} <- path_value(payload, Map.get(rule, "unit_path"), role, "unit") do
      {:ok,
       %{
         effect_type: effect_type,
         quantity: quantity,
         unit: unit,
         payload: %{"rule" => rule}
       }}
    end
  end

  defp effect_type(effect_type, role) do
    case Map.fetch(@effect_types, effect_type) do
      {:ok, effect_type} ->
        {:ok, effect_type}

      :error ->
        {:error, "Effect rule for role #{role} uses unsupported effect type #{effect_type}."}
    end
  end

  defp path_value(payload, path, role, field) do
    case PathReader.read(payload, path) do
      {:ok, value} ->
        {:ok, value}

      :error ->
        {:error, "Effect rule for role #{role} could not read #{field} at #{path}."}
    end
  end

  defp link_role(%{role: role}), do: role
  defp link_role(%{"role" => role}), do: role

  defp link_item_id(%{item_id: item_id}), do: item_id
  defp link_item_id(%{"item_id" => item_id}), do: item_id
end
