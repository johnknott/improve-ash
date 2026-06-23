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
      rules: Keyword.get(opts, :rules, %{})
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end
end
