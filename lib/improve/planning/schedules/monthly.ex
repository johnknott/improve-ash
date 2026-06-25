defmodule Improve.Planning.Schedules.Monthly do
  @moduledoc false

  @behaviour Improve.Planning.Schedules.Evaluator

  alias Improve.Planning.Schedules.Helpers

  def kind, do: :monthly

  def evaluate(%{schedule: %{rules: rules} = schedule, date: date}) do
    day = Map.get(rules || %{}, "day")

    case Helpers.parse_positive_integer(day) do
      nil ->
        {:ok, false, [day_diagnostic(schedule, day)]}

      day when day > 31 ->
        {:ok, false, [day_diagnostic(schedule, day)]}

      day ->
        {:ok, date.day == min(day, Date.days_in_month(date)), []}
    end
  end

  defp day_diagnostic(schedule, value) do
    %{
      code: :unsupported_schedule_rules,
      severity: :error,
      message: "Monthly schedules need a day rule between 1 and 31.",
      details: %{schedule_id: schedule.id, value: value}
    }
  end
end
