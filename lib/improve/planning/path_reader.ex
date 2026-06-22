defmodule Improve.Planning.PathReader do
  @moduledoc """
  Reads authored dot paths from explicit maps.

  Effect rules and diagnostics both use paths like `payload.amount` or
  `payload.nested.amount`. Keeping that interpretation in one tiny module keeps
  preview-time diagnostics and runtime effect interpretation in agreement.
  """

  def path(path) when is_binary(path) do
    path
    |> String.split(".")
    |> Enum.reject(&(&1 == ""))
  end

  def path(_path), do: []

  def read(source, path) when is_map(source) do
    path = path(path)

    source
    |> rooted_source(path)
    |> read_path(drop_root(path))
  end

  def read(_source, _path), do: :error

  def value(source, path) do
    case read(source, path) do
      {:ok, value} -> value
      :error -> nil
    end
  end

  defp rooted_source(source, ["payload" | _path]), do: source
  defp rooted_source(source, _path), do: source

  defp drop_root(["payload" | path]), do: path
  defp drop_root(path), do: path

  defp read_path(source, []) do
    {:ok, source}
  end

  defp read_path(source, [key | rest]) when is_map(source) do
    case map_fetch(source, key) do
      {:ok, value} -> read_path(value, rest)
      :error -> :error
    end
  end

  defp read_path(_source, _path), do: :error

  defp map_fetch(map, key) do
    atom_key = existing_atom(key)

    cond do
      Map.has_key?(map, key) ->
        {:ok, Map.fetch!(map, key)}

      not is_nil(atom_key) and Map.has_key?(map, atom_key) ->
        {:ok, Map.fetch!(map, atom_key)}

      true ->
        :error
    end
  end

  defp existing_atom(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end
end
