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
    Improve.Planning.Schedules.EveryNWeeks,
    Improve.Planning.Schedules.TimesPerWeek,
    Improve.Planning.Schedules.Monthly
  ]

  @implemented Map.new(@implemented_evaluators, &{&1.kind(), &1})
  @recognized_unsupported [:after_completion, :custom]

  @type diagnostic :: map()
  @type result :: {:ok, due? :: boolean(), diagnostics :: [diagnostic()]} | {:error, diagnostic()}
  @type support :: {:implemented, module()} | :recognized_unsupported | :unknown

  @spec decide(map(), Date.t(), map()) :: result()
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

  @doc """
  Product-language cadence for a schedule ("Every day", "3× a week"), or nil
  when the kind has no friendly description.
  """
  @spec describe(map() | nil) :: String.t() | nil
  def describe(nil), do: nil

  def describe(schedule) do
    rules = Map.get(schedule, :rules) || %{}

    case Map.get(schedule, :kind) do
      :every_day -> "Every day"
      :times_per_week -> times_per_week_description(rules)
      :selected_weekdays -> weekdays_description(rules)
      :every_n_days -> interval_description(rules, ["interval_days", "days"], "day")
      :every_n_weeks -> interval_description(rules, ["interval_weeks", "weeks"], "week")
      :monthly -> monthly_description(rules)
      _other -> nil
    end
  end

  defp times_per_week_description(rules) do
    case rule_number(rules, ["times", "count"]) do
      1 -> "Once a week"
      times when is_integer(times) -> "#{times}× a week"
      _other -> "A few times a week"
    end
  end

  defp weekdays_description(rules) do
    case Map.get(rules, "weekdays") do
      weekdays when is_list(weekdays) and weekdays != [] ->
        "Every " <> join_names(Enum.map(weekdays, &short_weekday/1))

      _other ->
        "On selected weekdays"
    end
  end

  defp interval_description(rules, keys, unit) do
    case rule_number(rules, keys) do
      1 -> "Every #{unit}"
      count when is_integer(count) -> "Every #{count} #{unit}s"
      _other -> nil
    end
  end

  defp monthly_description(rules) do
    case rule_number(rules, ["day"]) do
      day when is_integer(day) -> "Monthly on day #{day}"
      _other -> "Monthly"
    end
  end

  defp rule_number(rules, keys) do
    keys
    |> Enum.find_value(&Map.get(rules, &1))
    |> case do
      value when is_integer(value) -> value
      value when is_binary(value) -> with({n, ""} <- Integer.parse(value), do: n)
      _other -> nil
    end
  end

  defp short_weekday(weekday) do
    weekday |> to_string() |> String.slice(0, 3) |> String.capitalize()
  end

  defp join_names([single]), do: single

  defp join_names(names) do
    {rest, [last]} = Enum.split(names, -1)
    Enum.join(rest, ", ") <> " and " <> last
  end

  @spec support(atom()) :: support()
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
