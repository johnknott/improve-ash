defmodule Improve.App.Today do
  @moduledoc """
  Product-facing projection operations.
  """

  alias Improve.Plans

  def project_today!(plan, opts) do
    projection_opts =
      [actor: Keyword.fetch!(opts, :actor), date: Keyword.fetch!(opts, :date)]
      |> maybe_put(:as_of_date, Keyword.get(opts, :as_of_date))

    Plans.project_today!(plan, projection_opts)
  end

  defp maybe_put(list, _key, nil), do: list
  defp maybe_put(list, key, value), do: Keyword.put(list, key, value)
end
