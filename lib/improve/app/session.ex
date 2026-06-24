defmodule Improve.App.Session do
  @moduledoc """
  Small product-facing constructors for session authoring.
  """

  def choose(count, opts) do
    %{
      count: count,
      from: Keyword.fetch!(opts, :from),
      key: Keyword.get(opts, :key),
      name: Keyword.get(opts, :name),
      optional: Keyword.get(opts, :optional, false),
      rules: rules(opts)
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp rules(opts) do
    opts
    |> Keyword.get(:rules, %{})
    |> maybe_put(:suggestion_target, Keyword.get(opts, :suggest))
    |> maybe_put(:cold_start_payload, Keyword.get(opts, :start_with))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
