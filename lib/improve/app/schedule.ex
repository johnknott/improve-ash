defmodule Improve.App.Schedule do
  @moduledoc """
  Small product-facing constructors for authored schedules.
  """

  def every_day, do: %{kind: :every_day, rules: %{}}

  def selected_weekdays(days) do
    %{
      kind: :selected_weekdays,
      rules: %{"weekdays" => Enum.map(days, &weekday/1)}
    }
  end

  def every_n_days(days) when is_integer(days) and days > 0 do
    %{
      kind: :every_n_days,
      rules: %{"interval_days" => days}
    }
  end

  def times_per_week(times, opts \\ []) when is_integer(times) and times > 0 do
    %{
      kind: :times_per_week,
      rules: %{
        "times" => times,
        "allowed_weekdays" => opts |> Keyword.get(:on, all_weekdays()) |> Enum.map(&weekday/1)
      }
    }
    |> put_minimum_gap_days(opts)
  end

  def every_week(opts) do
    times_per_week(Keyword.fetch!(opts, :times), on: Keyword.fetch!(opts, :on))
  end

  def every_n_weeks(weeks, opts) when is_integer(weeks) and weeks > 0 do
    %{
      kind: :every_n_weeks,
      rules: %{
        "interval_weeks" => weeks,
        "weekdays" => opts |> Keyword.fetch!(:on) |> List.wrap() |> Enum.map(&weekday/1)
      }
    }
  end

  def monthly(opts) do
    %{
      kind: :monthly,
      rules: %{"day" => Keyword.fetch!(opts, :day)}
    }
  end

  def after_completion(opts) do
    %{
      kind: :after_completion,
      rules: %{"days" => Keyword.fetch!(opts, :days)}
    }
  end

  def custom(description) when is_binary(description) do
    %{
      kind: :custom,
      rules: %{"description" => description}
    }
  end

  defp put_minimum_gap_days(schedule, opts) do
    case Keyword.get(opts, :minimum_gap_days) do
      nil -> schedule
      days -> put_in(schedule, [:rules, "minimum_gap_days"], days)
    end
  end

  defp all_weekdays do
    [:monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday]
  end

  defp weekday(day) when is_atom(day), do: Atom.to_string(day)
  defp weekday(day) when is_binary(day), do: day
end
