defmodule Improve.Planning.Schedules.SelectedWeekdays do
  @moduledoc false

  @behaviour Improve.Planning.Schedules.Evaluator

  alias Improve.Planning.Schedules.Helpers

  def kind, do: :selected_weekdays

  def evaluate(%{schedule: %{rules: rules}, date: date}) do
    {:ok, Helpers.weekday(date) in Map.get(rules, "weekdays", []), []}
  end
end
