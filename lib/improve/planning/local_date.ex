defmodule Improve.Planning.LocalDate do
  @moduledoc """
  Converts journal timestamps to the calendar date they belong to in the
  user's time zone.

  Journal events store `effective_at` in UTC. "Which day did this happen"
  is a product question answered in the user's local time zone, not UTC —
  a 21:00 workout in New York belongs to that local day even though its
  UTC timestamp has already rolled over.

  Falls back to the UTC date when the time zone is unknown so a bad or
  missing zone degrades to the old behaviour instead of crashing a
  projection.
  """

  @default_timezone "Etc/UTC"

  def default_timezone, do: @default_timezone

  @spec to_date(DateTime.t() | NaiveDateTime.t() | Date.t() | nil, String.t() | nil) ::
          Date.t() | nil
  def to_date(value, timezone \\ @default_timezone)

  def to_date(%DateTime{} = datetime, timezone) do
    case DateTime.shift_zone(datetime, timezone || @default_timezone) do
      {:ok, shifted} -> DateTime.to_date(shifted)
      {:error, _reason} -> DateTime.to_date(datetime)
    end
  end

  def to_date(%NaiveDateTime{} = datetime, _timezone), do: NaiveDateTime.to_date(datetime)
  def to_date(%Date{} = date, _timezone), do: date
  def to_date(_value, _timezone), do: nil
end
