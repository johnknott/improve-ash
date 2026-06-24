defmodule Improve.Planning.Schedules do
  @moduledoc """
  Internal schedule projection dispatcher.

  The projector asks this module whether one schedule applies on one date. The
  registry keeps the support tiers in one place without making this a public
  extension surface.
  """

  alias Improve.Planning.Schedules.Evaluation

  @implemented_evaluators [
    Improve.Planning.Schedules.EveryDay,
    Improve.Planning.Schedules.SelectedWeekdays,
    Improve.Planning.Schedules.EveryNDays,
    Improve.Planning.Schedules.TimesPerWeek
  ]

  @implemented Map.new(@implemented_evaluators, &{&1.kind(), &1})
  @recognized_unsupported [:after_completion, :custom, :every_n_weeks, :monthly]

  def decide(schedule, date, input) do
    case support(schedule.kind) do
      {:implemented, evaluator} ->
        evaluator.evaluate(%Evaluation{schedule: schedule, date: date, input: input})

      :recognized_unsupported ->
        {:ok, false, [recognized_unsupported_diagnostic(schedule)]}

      :unknown ->
        {:error, unknown_diagnostic(schedule)}
    end
  end

  def support(kind) do
    cond do
      Map.has_key?(@implemented, kind) -> {:implemented, Map.fetch!(@implemented, kind)}
      kind in @recognized_unsupported -> :recognized_unsupported
      true -> :unknown
    end
  end

  defp recognized_unsupported_diagnostic(schedule) do
    %{
      code: :recognized_unsupported_schedule_kind,
      severity: :info,
      message: "This schedule kind is recognized, but projection support is not implemented yet.",
      details: %{schedule_id: schedule.id, kind: schedule.kind}
    }
  end

  defp unknown_diagnostic(schedule) do
    %{
      code: :unsupported_schedule_kind,
      severity: :warning,
      message: "Schedule kind is not recognized by the projector.",
      details: %{schedule_id: schedule.id, kind: schedule.kind}
    }
  end
end
