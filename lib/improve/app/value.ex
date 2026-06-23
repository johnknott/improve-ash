defmodule Improve.App.Value do
  @moduledoc false

  def key_from(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "_")
    |> String.trim("_")
  end

  def stringify_keys(value) when is_map(value) do
    Map.new(value, fn {key, value} -> {stringify_key(key), stringify_keys(value)} end)
  end

  def stringify_keys(value) when is_list(value), do: Enum.map(value, &stringify_keys/1)
  def stringify_keys(value), do: value

  def stringify_key(key) when is_atom(key), do: Atom.to_string(key)
  def stringify_key(key), do: key

  def value(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, existing_atom(key))
  end

  def value(_map, _key), do: nil

  def maybe_put(map, _key, nil), do: map
  def maybe_put(map, key, value), do: Map.put(map, key, value)

  def default_datetime(date) do
    DateTime.new!(date, ~T[20:00:00], "Etc/UTC")
  end

  defp existing_atom(key) when is_binary(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end

  defp existing_atom(key), do: key
end
