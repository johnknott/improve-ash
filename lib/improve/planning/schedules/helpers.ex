defmodule Improve.Planning.Schedules.Helpers do
  @moduledoc false

  @weekdays %{
    1 => "monday",
    2 => "tuesday",
    3 => "wednesday",
    4 => "thursday",
    5 => "friday",
    6 => "saturday",
    7 => "sunday"
  }

  def weekdays, do: Map.values(@weekdays)

  def weekday(date), do: Map.fetch!(@weekdays, Date.day_of_week(date))

  def in_date_range?(date, starts_on, nil), do: Date.compare(date, starts_on) != :lt

  def in_date_range?(date, starts_on, ends_on) do
    Date.compare(date, starts_on) != :lt and Date.compare(date, ends_on) != :gt
  end

  def dates_through(start_date, end_date) do
    0..Date.diff(end_date, start_date)
    |> Enum.map(&Date.add(start_date, &1))
  end

  def positive_integer(value, default), do: max(non_negative_integer(value, default), 1)

  def parse_positive_integer(value) when is_integer(value) and value > 0, do: value

  def parse_positive_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} when integer > 0 -> integer
      _other -> nil
    end
  end

  def parse_positive_integer(_value), do: nil

  def non_negative_integer(value, _default) when is_integer(value) and value >= 0, do: value

  def non_negative_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} when integer >= 0 -> integer
      _other -> default
    end
  end

  def non_negative_integer(_value, default), do: default
end
