defmodule Improve.Planning.Schedules.TimesPerWeek do
  @moduledoc false

  @behaviour Improve.Planning.Schedules.Evaluator

  alias Improve.Planning.Schedules.Helpers

  def kind, do: :times_per_week

  def evaluate(%{schedule: schedule, date: date, input: input}) do
    quota = quota_plan(schedule, date, input)
    {:ok, date in quota.due_dates, quota.diagnostics}
  end

  defp quota_plan(schedule, date, input) do
    rules = schedule.rules || %{}
    times = Helpers.positive_integer(Map.get(rules, "times", Map.get(rules, "count", 1)), 1)
    minimum_gap_days = Helpers.non_negative_integer(Map.get(rules, "minimum_gap_days", 0), 0)
    {allowed_weekdays, rule_diagnostics} = allowed_weekdays(schedule, rules)
    {week_start, week_end} = week_bounds(date)
    as_of_date = Map.get(input, :as_of_date, date)
    placement_start = quota_placement_start(date, as_of_date, week_start)

    candidate_dates =
      week_start
      |> Helpers.dates_through(week_end)
      |> Enum.filter(fn candidate_date ->
        Helpers.in_date_range?(candidate_date, schedule.starts_on, schedule.ends_on) and
          Helpers.weekday(candidate_date) in allowed_weekdays
      end)

    completed_dates =
      schedule
      |> completed_dates(input)
      |> Enum.filter(&Helpers.in_date_range?(&1, week_start, week_end))
      |> Enum.uniq()
      |> Enum.sort_by(& &1, Date)

    remaining = max(times - length(completed_dates), 0)

    placed_dates =
      candidate_dates
      |> Enum.reject(&(&1 in completed_dates))
      |> Enum.reject(&(Date.compare(&1, placement_start) == :lt))
      |> place_quota_dates(remaining, completed_dates, minimum_gap_days)

    (completed_dates ++ placed_dates)
    |> Enum.uniq()
    |> Enum.sort_by(& &1, Date)
    |> then(fn due_dates ->
      %{
        due_dates: due_dates,
        diagnostics:
          rule_diagnostics ++
            quota_diagnostics(schedule, times, candidate_dates, completed_dates, placed_dates)
      }
    end)
  end

  defp allowed_weekdays(schedule, rules) do
    case Map.get(rules, "allowed_weekdays") do
      nil ->
        {Helpers.weekdays(), []}

      weekdays when is_list(weekdays) ->
        {weekdays, []}

      other ->
        {[],
         [
           %{
             code: :unsupported_schedule_rules,
             severity: :error,
             message: "Schedule allowed weekdays must be a list of weekday names.",
             details: %{schedule_id: schedule.id, value: other}
           }
         ]}
    end
  end

  defp quota_diagnostics(schedule, times, candidate_dates, completed_dates, placed_dates) do
    placed_count = length(completed_dates) + length(placed_dates)

    cond do
      candidate_dates == [] and completed_dates == [] ->
        [
          %{
            code: :unplaceable_schedule,
            severity: :warning,
            message:
              "Schedule cannot place any work this week because no allowed dates fall inside the schedule range.",
            details: %{schedule_id: schedule.id, requested: times, placed: 0}
          }
        ]

      placed_count < times ->
        [
          %{
            code: :partially_placeable_schedule,
            severity: :warning,
            message:
              "Schedule can only place #{placed_count} of #{times} requested occurrence(s) this week with the current allowed weekdays and minimum gap.",
            details: %{schedule_id: schedule.id, requested: times, placed: placed_count}
          }
        ]

      true ->
        []
    end
  end

  defp place_quota_dates(_candidate_dates, 0, _occupied_dates, _minimum_gap_days), do: []

  defp place_quota_dates(candidate_dates, remaining, occupied_dates, minimum_gap_days) do
    candidate_dates
    |> Enum.reduce_while([], fn candidate_date, placed_dates ->
      cond do
        length(placed_dates) == remaining ->
          {:halt, placed_dates}

        gap_ok?(candidate_date, occupied_dates ++ placed_dates, minimum_gap_days) ->
          {:cont, placed_dates ++ [candidate_date]}

        true ->
          {:cont, placed_dates}
      end
    end)
  end

  defp completed_dates(%{owner_type: :track, owner_id: owner_id}, input) do
    timezone = Map.get(input, :timezone) || Improve.Planning.LocalDate.default_timezone()

    input
    |> Map.get(:journal_events, [])
    |> Enum.filter(&(&1.track_id == owner_id and &1.status == :active))
    |> Enum.map(&Improve.Planning.LocalDate.to_date(&1.effective_at, timezone))
  end

  defp completed_dates(%{owner_type: :session_template, owner_id: owner_id}, input) do
    input
    |> Map.get(:session_occurrences, [])
    |> Enum.filter(&(&1.session_template_id == owner_id and &1.status == :completed))
    |> Enum.map(& &1.planned_for)
  end

  defp completed_dates(_schedule, _input), do: []

  defp gap_ok?(_date, [], _minimum_gap_days), do: true

  defp gap_ok?(date, occupied_dates, minimum_gap_days) do
    Enum.all?(occupied_dates, &(abs(Date.diff(date, &1)) > minimum_gap_days))
  end

  defp week_bounds(date) do
    week_start = Date.add(date, 1 - Date.day_of_week(date))
    {week_start, Date.add(week_start, 6)}
  end

  defp quota_placement_start(date, as_of_date, week_start) do
    if Date.compare(date, as_of_date) == :eq do
      week_start
    else
      max_date(week_start, as_of_date)
    end
  end

  defp max_date(left, right) do
    case Date.compare(left, right) do
      :lt -> right
      _other -> left
    end
  end
end
