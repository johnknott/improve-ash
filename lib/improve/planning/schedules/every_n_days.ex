defmodule Improve.Planning.Schedules.EveryNDays do
  @moduledoc false

  @behaviour Improve.Planning.Schedules.Evaluator

  alias Improve.Planning.Schedules.Helpers

  def kind, do: :every_n_days

  def evaluate(%{schedule: %{rules: rules} = schedule, date: date}) do
    interval_days = Map.get(rules, "interval_days", Map.get(rules, "days"))

    case Helpers.parse_positive_integer(interval_days) do
      nil ->
        {:ok, false,
         [
           %{
             code: :unsupported_schedule_rules,
             severity: :error,
             message: "Every-N-days schedules need a positive interval_days rule.",
             details: %{schedule_id: schedule.id, value: interval_days}
           }
         ]}

      interval_days ->
        due? = rem(Date.diff(date, schedule.starts_on), interval_days) == 0
        {:ok, due?, []}
    end
  end
end
