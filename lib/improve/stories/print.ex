defmodule Improve.Stories.Print do
  @moduledoc """
  Small printing helpers for product story scripts.

  These functions format records for human inspection only. They do not assert,
  interpret product rules, or calculate product state.
  """

  def section(title) do
    IO.puts("")
    IO.puts("== #{title} ==")
  end

  def key_values(values) do
    Enum.each(values, fn {label, value} ->
      IO.puts("#{label}: #{format(value)}")
    end)
  end

  def inspect_value(label, value) do
    IO.puts("#{label}:")
    IO.inspect(value, pretty: true, limit: :infinity)
  end

  def rows([], _formatter) do
    IO.puts("(none)")
  end

  def rows(records, formatter) do
    Enum.each(records, fn record ->
      IO.puts("- #{formatter.(record)}")
    end)
  end

  defp format(%Date{} = date), do: Date.to_iso8601(date)
  defp format(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
  defp format(%Decimal{} = decimal), do: Decimal.to_string(decimal)
  defp format(value) when is_atom(value), do: Atom.to_string(value)
  defp format(value), do: to_string(value)
end
