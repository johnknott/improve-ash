defmodule Improve.App.Target do
  @moduledoc """
  Product-facing constructors for track targets and recorded values.
  """

  def fixed(quantity, unit, opts \\ []) do
    %{
      type: :fixed,
      quantity: quantity,
      unit: unit
    }
    |> maybe_put(:quantity_path, Keyword.get(opts, :quantity_path))
    |> maybe_put(:summary_template, Keyword.get(opts, :summary_template))
  end

  def metric(name, opts \\ []) do
    %{
      type: :metric,
      metric: name
    }
    |> maybe_put(:unit, Keyword.get(opts, :unit))
  end

  def checklist(items) when is_list(items) do
    %{
      type: :checklist,
      items: items
    }
  end

  def period_total(quantity, unit, opts) do
    %{
      type: :period_total,
      quantity: quantity,
      unit: unit,
      per: Keyword.fetch!(opts, :per)
    }
  end

  def progression(opts) do
    progression(Keyword.fetch!(opts, :from), Keyword.fetch!(opts, :to), opts)
  end

  def progression(from, to, opts \\ []) do
    %{
      type: :progression,
      from: from,
      to: to
    }
    |> maybe_put(:unit, Keyword.get(opts, :unit))
    |> maybe_put(:shape, Keyword.get(opts, :shape))
  end

  def adaptive(opts) do
    %{
      type: :adaptive,
      fields: Keyword.fetch!(opts, :fields)
    }
    |> maybe_put(:effort, Keyword.get(opts, :effort))
    |> maybe_put(:review, Keyword.get(opts, :review))
  end

  def number(unit, opts \\ []) do
    field = opts |> Keyword.get(:field, :amount) |> field_name()

    %{
      type: :number,
      field: field,
      unit: unit,
      quantity_path: "payload.#{field}"
    }
  end

  def amount(unit, opts \\ []), do: number(unit, opts)

  def fields(fields) when is_list(fields) do
    %{
      type: :fields,
      fields: Enum.map(fields, &field_name/1)
    }
  end

  def apply_records(target, nil), do: target || %{}

  def apply_records(target, records) when is_map(records),
    do: merge_record_metadata(target || %{}, records)

  defp merge_record_metadata(target, records) do
    target
    |> put_new(:quantity_path, Map.get(records, :quantity_path))
    |> put_new(:unit, Map.get(records, :unit))
    |> maybe_put(:records, Map.delete(records, :quantity_path))
  end

  defp put_new(map, _key, nil), do: map
  defp put_new(map, key, value), do: Map.put_new(map, key, value)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp field_name(field) when is_atom(field), do: Atom.to_string(field)
  defp field_name(field) when is_binary(field), do: field
end
