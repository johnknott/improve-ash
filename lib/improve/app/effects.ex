defmodule Improve.App.Effects do
  @moduledoc """
  Small product-facing constructors for authored event effects.
  """

  def subtract_quantity(opts) do
    %{
      role: Keyword.fetch!(opts, :from),
      effect_type: "subtract_quantity",
      quantity_path: Keyword.fetch!(opts, :quantity),
      unit_path: Keyword.fetch!(opts, :unit)
    }
  end
end
