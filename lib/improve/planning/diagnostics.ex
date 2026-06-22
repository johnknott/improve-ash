defmodule Improve.Planning.Diagnostics do
  @moduledoc """
  Plain-English diagnostics for authored plan content.
  """

  def validate_event_type(event_type) do
    roles =
      event_type.item_link_roles
      |> Map.get("roles", [])
      |> Enum.map(&Map.get(&1, "role"))
      |> MapSet.new()

    event_type.effect_rules
    |> Map.get("rules", [])
    |> Enum.flat_map(&validate_effect_rule(&1, roles))
  end

  defp validate_effect_rule(rule, roles) do
    role = Map.get(rule, "role")

    cond do
      is_nil(role) ->
        [
          diagnostic(:effect_rule_missing_role, "Effect rule is missing an item link role.", %{
            rule: rule
          })
        ]

      not MapSet.member?(roles, role) ->
        [
          diagnostic(
            :effect_rule_unknown_role,
            "Effect rule refers to an item link role that is not declared.",
            %{
              role: role
            }
          )
        ]

      true ->
        []
    end
  end

  defp diagnostic(code, message, details), do: %{code: code, message: message, details: details}
end
