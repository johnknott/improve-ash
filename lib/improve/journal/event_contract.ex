defmodule Improve.Journal.EventContract do
  @moduledoc """
  Runtime validation for a log command against its authored event type.

  Draft diagnostics can catch many authoring mistakes before install, but live
  logging still needs to enforce the event type contract before writing journal
  history.
  """

  alias Improve.Planning.PathReader

  # Skips record a decision, not data — the event type's payload and item
  # link contract only applies to active events.
  def validate(_event_type, %{status: :skipped}), do: []

  def validate(event_type, command) do
    validate_item_link_roles(event_type.item_link_roles || %{}, command.item_links) ++
      validate_payload_schema(event_type.payload_schema || %{}, command.payload || %{})
  end

  defp validate_item_link_roles(item_link_roles, item_links) do
    roles = roles(item_link_roles)
    declared_roles = roles |> Enum.map(&role_name/1) |> Enum.reject(&blank?/1) |> MapSet.new()
    submitted_roles = item_links |> Enum.map(&link_role/1) |> Enum.reject(&blank?/1)

    required_role_diagnostics(roles, submitted_roles) ++
      unknown_role_diagnostics(declared_roles, submitted_roles)
  end

  defp required_role_diagnostics(roles, submitted_roles) do
    Enum.flat_map(roles, fn role ->
      role_name = role_name(role)

      if required?(role) and role_name not in submitted_roles do
        ["Event type requires item link role #{role_name}."]
      else
        []
      end
    end)
  end

  defp unknown_role_diagnostics(declared_roles, submitted_roles) do
    if MapSet.size(declared_roles) == 0 do
      []
    else
      submitted_roles
      |> Enum.uniq()
      |> Enum.reject(&MapSet.member?(declared_roles, &1))
      |> Enum.map(&"Event command uses unsupported item link role #{&1}.")
    end
  end

  defp validate_payload_schema(payload_schema, payload) do
    payload_schema
    |> list("required")
    |> Enum.flat_map(fn path ->
      if present?(PathReader.value(payload, path)) do
        []
      else
        ["Event type requires payload field #{path}."]
      end
    end)
  end

  defp roles(item_link_roles), do: list(item_link_roles, "roles")

  defp list(map, key) when is_map(map) do
    case map_value(map, key, []) do
      values when is_list(values) -> values
      _other -> []
    end
  end

  defp list(_map, _key), do: []

  defp map_value(map, key, default) do
    cond do
      Map.has_key?(map, key) ->
        Map.fetch!(map, key)

      atom_key = existing_atom(key) ->
        Map.get(map, atom_key, default)

      true ->
        default
    end
  end

  defp existing_atom(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end

  defp role_name(%{"role" => role}), do: role
  defp role_name(%{role: role}), do: role
  defp role_name(_role), do: nil

  defp required?(%{"required" => required}), do: required == true
  defp required?(%{required: required}), do: required == true
  defp required?(_role), do: false

  defp link_role(%{role: role}), do: role
  defp link_role(%{"role" => role}), do: role
  defp link_role(_link), do: nil

  defp present?(nil), do: false
  defp present?(""), do: false
  defp present?([]), do: false
  defp present?(_value), do: true

  defp blank?(value), do: not present?(value)
end
