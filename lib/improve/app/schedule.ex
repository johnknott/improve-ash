defmodule Improve.App.Schedule do
  @moduledoc """
  Small product-facing constructors for authored schedules.
  """

  def every_day, do: %{kind: :every_day, rules: %{}}

  def every_week(opts) do
    %{
      kind: :times_per_week,
      rules: %{
        "times" => Keyword.fetch!(opts, :times),
        "allowed_weekdays" => opts |> Keyword.fetch!(:on) |> Enum.map(&weekday/1)
      }
    }
  end

  defp weekday(day) when is_atom(day), do: Atom.to_string(day)
  defp weekday(day) when is_binary(day), do: day
end
