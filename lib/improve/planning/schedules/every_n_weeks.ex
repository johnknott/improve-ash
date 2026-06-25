defmodule Improve.Planning.Schedules.EveryNWeeks do
  @moduledoc false

  @behaviour Improve.Planning.Schedules.Evaluator

  alias Improve.Planning.Schedules.Helpers

  def kind, do: :every_n_weeks

  def evaluate(%{schedule: %{rules: rules} = schedule, date: date}) do
    interval_weeks = Map.get(rules || %{}, "interval_weeks", Map.get(rules || %{}, "weeks"))
    weekdays = Map.get(rules || %{}, "weekdays", [])

    with {:ok, interval_weeks} <- parse_interval(schedule, interval_weeks),
         {:ok, weekdays} <- parse_weekdays(schedule, weekdays) do
      weeks_since_start = div(Date.diff(date, schedule.starts_on), 7)
      due? = rem(weeks_since_start, interval_weeks) == 0 and Helpers.weekday(date) in weekdays

      {:ok, due?, []}
    else
      {:error, diagnostic} -> {:ok, false, [diagnostic]}
    end
  end

  defp parse_interval(schedule, value) do
    case Helpers.parse_positive_integer(value) do
      nil ->
        {:error,
         %{
           code: :unsupported_schedule_rules,
           severity: :error,
           message: "Every-N-weeks schedules need a positive interval_weeks rule.",
           details: %{schedule_id: schedule.id, value: value}
         }}

      interval ->
        {:ok, interval}
    end
  end

  defp parse_weekdays(_schedule, weekdays) when is_list(weekdays), do: {:ok, weekdays}

  defp parse_weekdays(schedule, weekdays) do
    {:error,
     %{
       code: :unsupported_schedule_rules,
       severity: :error,
       message: "Every-N-weeks schedules need a weekdays list.",
       details: %{schedule_id: schedule.id, value: weekdays}
     }}
  end
end
