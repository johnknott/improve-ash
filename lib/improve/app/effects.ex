defmodule Improve.App.Effects do
  @moduledoc """
  Small product-facing constructors for authored event effects.
  """

  def subtract_quantity(opts) do
    %{
      role: Keyword.get(opts, :from) || Keyword.fetch!(opts, :item),
      effect_type: "subtract_quantity",
      quantity_path: Keyword.fetch!(opts, :quantity),
      unit_path: Keyword.fetch!(opts, :unit)
    }
  end

  def add_quantity(opts) do
    %{
      role: Keyword.get(opts, :to) || Keyword.fetch!(opts, :item),
      effect_type: "add_quantity",
      quantity_path: Keyword.fetch!(opts, :quantity),
      unit_path: Keyword.fetch!(opts, :unit)
    }
  end

  def set_quantity(opts) do
    %{
      role: Keyword.get(opts, :for) || Keyword.fetch!(opts, :item),
      effect_type: "set_quantity",
      quantity_path: Keyword.fetch!(opts, :quantity),
      unit_path: Keyword.fetch!(opts, :unit)
    }
  end
end
