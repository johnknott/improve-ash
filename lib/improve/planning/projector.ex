defmodule Improve.Planning.Projector do
  @moduledoc """
  Pure projection of planned work for explicit dates and records.
  """

  alias Improve.Planning.ProjectedWork
  alias Improve.Planning.Recommender

  @weekdays %{
    1 => "monday",
    2 => "tuesday",
    3 => "wednesday",
    4 => "thursday",
    5 => "friday",
    6 => "saturday",
    7 => "sunday"
  }

  def project_today(input) do
    date = Map.fetch!(input, :date)
    plan = Map.fetch!(input, :plan)
    templates = Map.fetch!(input, :session_templates)

    {occurrences, session_diagnostics} =
      project_entries(templates, &template_projection(&1, input))

    {direct_goal_work, direct_goal_diagnostics} =
      project_entries(Map.get(input, :direct_goals, []), &direct_goal_projection(&1, input))

    occurrences = Enum.reverse(occurrences)
    direct_goal_work = Enum.reverse(direct_goal_work)
    projected_work = Enum.map(occurrences, &ProjectedWork.session/1) ++ direct_goal_work

    %{
      plan_id: plan.id,
      date: date,
      projected_session_occurrences: occurrences,
      projected_work: projected_work,
      input_summary: input_summary(input),
      diagnostics: Enum.reverse(session_diagnostics) ++ Enum.reverse(direct_goal_diagnostics),
      explanations: explanations(projected_work)
    }
  end

  defp project_entries(entries, project_fun) do
    entries
    |> Enum.sort_by(& &1.key)
    |> Enum.reduce({[], []}, fn entry, {projections, diagnostics} ->
      case project_fun.(entry) do
        {:ok, nil} -> {projections, diagnostics}
        {:ok, projection} -> {[projection | projections], diagnostics}
        {:error, diagnostic} -> {projections, [diagnostic | diagnostics]}
      end
    end)
  end

  defp template_projection(template, input) do
    date = Map.fetch!(input, :date)
    plan = Map.fetch!(input, :plan)
    schedules = schedules_for(input.schedules, :session_template, template.id)

    cond do
      not in_date_range?(date, plan.starts_on, plan.ends_on) ->
        {:ok, nil}

      schedules == [] ->
        {:ok, nil}

      true ->
        case Enum.reduce_while(schedules, {:ok, false}, &schedule_decision(&1, date, input, &2)) do
          {:ok, true} -> {:ok, occurrence_projection(template, input)}
          {:ok, false} -> {:ok, nil}
          {:error, diagnostic} -> {:error, diagnostic}
        end
    end
  end

  defp direct_goal_projection(goal, input) do
    date = Map.fetch!(input, :date)
    plan = Map.fetch!(input, :plan)
    schedules = schedules_for(input.schedules, :direct_goal, goal.id)

    cond do
      not in_date_range?(date, plan.starts_on, plan.ends_on) ->
        {:ok, nil}

      schedules == [] ->
        {:ok, nil}

      true ->
        case Enum.reduce_while(schedules, {:ok, false}, &schedule_decision(&1, date, input, &2)) do
          {:ok, true} -> {:ok, direct_goal_work(goal, input)}
          {:ok, false} -> {:ok, nil}
          {:error, diagnostic} -> {:error, diagnostic}
        end
    end
  end

  defp occurrence_projection(template, input) do
    slots =
      input.session_slots
      |> Enum.filter(&(&1.session_template_id == template.id))
      |> Enum.sort_by(&{&1.position, &1.key})

    environment = Enum.find(input.environments, &(&1.id == template.environment_id))

    recommendations =
      Enum.map(slots, fn slot ->
        %{
          session_slot_id: slot.id,
          slot_key: slot.key,
          slot_name: slot.name,
          count: slot.count,
          recommended_items:
            Recommender.recommend_slot(slot, %{
              items: input.items,
              pool_memberships: input.pool_memberships,
              environment: environment,
              recent_item_ids: Map.get(input, :recent_item_ids, [])
            })
        }
      end)

    %{
      plan_id: input.plan.id,
      session_template_id: template.id,
      session_template_name: template.name,
      planned_for: input.date,
      recommendations: recommendations
    }
  end

  defp direct_goal_work(goal, input) do
    completed_events = completed_direct_goal_events(goal, input)

    status =
      direct_goal_status(input.date, Map.get(input, :as_of_date, input.date), completed_events)

    ProjectedWork.direct_goal(goal,
      planned_for: input.date,
      status: status,
      completed_event_ids: Enum.map(completed_events, & &1.id),
      explanation: direct_goal_explanation(goal, status, completed_events)
    )
  end

  defp completed_direct_goal_events(goal, input) do
    input
    |> Map.get(:journal_events, [])
    |> Enum.filter(fn event ->
      event.direct_goal_id == goal.id and event.status == :active and
        Date.compare(DateTime.to_date(event.effective_at), input.date) == :eq
    end)
  end

  defp direct_goal_status(_date, _as_of_date, [_event | _events]), do: :completed

  defp direct_goal_status(date, as_of_date, []) do
    if Date.compare(date, as_of_date) == :lt do
      :missed
    else
      :planned
    end
  end

  defp direct_goal_explanation(goal, :completed, events) do
    "Projected #{goal.name} as completed from #{length(events)} linked journal event(s)."
  end

  defp direct_goal_explanation(goal, :missed, _events) do
    "Projected #{goal.name} as missed because the date has passed without a linked journal event."
  end

  defp direct_goal_explanation(goal, :planned, _events) do
    "Projected #{goal.name} from its direct goal schedule."
  end

  defp schedule_decision(schedule, date, input, {:ok, matched?}) do
    if not in_date_range?(date, schedule.starts_on, schedule.ends_on) do
      {:cont, {:ok, matched?}}
    else
      case schedule_applies?(schedule, date, input) do
        {:ok, true} -> {:halt, {:ok, true}}
        {:ok, false} -> {:cont, {:ok, matched?}}
        {:error, diagnostic} -> {:halt, {:error, diagnostic}}
      end
    end
  end

  defp schedule_applies?(%{kind: :every_day}, _date, _input), do: {:ok, true}

  defp schedule_applies?(%{kind: :selected_weekdays, rules: rules}, date, _input) do
    {:ok, weekday(date) in Map.get(rules, "weekdays", [])}
  end

  defp schedule_applies?(%{kind: :times_per_week} = schedule, date, input) do
    {:ok, date in quota_due_dates(schedule, date, input)}
  end

  defp schedule_applies?(schedule, _date, _input) do
    {:error,
     %{
       code: :unsupported_schedule_kind,
       message: "Schedule kind is not supported by the POC projector.",
       details: %{schedule_id: schedule.id, kind: schedule.kind}
     }}
  end

  defp quota_due_dates(schedule, date, input) do
    rules = schedule.rules || %{}
    times = positive_integer(Map.get(rules, "times", Map.get(rules, "count", 1)), 1)
    minimum_gap_days = non_negative_integer(Map.get(rules, "minimum_gap_days", 0), 0)
    allowed_weekdays = Map.get(rules, "allowed_weekdays", Map.values(@weekdays))
    {week_start, week_end} = week_bounds(date)

    candidate_dates =
      week_start
      |> dates_through(week_end)
      |> Enum.filter(fn candidate_date ->
        in_date_range?(candidate_date, schedule.starts_on, schedule.ends_on) and
          weekday(candidate_date) in allowed_weekdays
      end)

    completed_dates =
      schedule
      |> completed_dates(input)
      |> Enum.filter(&in_date_range?(&1, week_start, week_end))
      |> Enum.uniq()
      |> Enum.sort_by(& &1, Date)

    remaining = max(times - length(completed_dates), 0)

    placed_dates =
      candidate_dates
      |> Enum.reject(&(&1 in completed_dates))
      |> place_quota_dates(remaining, completed_dates, minimum_gap_days)

    (completed_dates ++ placed_dates)
    |> Enum.uniq()
    |> Enum.sort_by(& &1, Date)
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

  defp completed_dates(%{owner_type: :direct_goal, owner_id: owner_id}, input) do
    input
    |> Map.get(:journal_events, [])
    |> Enum.filter(&(&1.direct_goal_id == owner_id and &1.status == :active))
    |> Enum.map(&DateTime.to_date(&1.effective_at))
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

  defp dates_through(start_date, end_date) do
    0..Date.diff(end_date, start_date)
    |> Enum.map(&Date.add(start_date, &1))
  end

  defp positive_integer(value, default), do: max(non_negative_integer(value, default), 1)

  defp non_negative_integer(value, _default) when is_integer(value) and value >= 0, do: value

  defp non_negative_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} when integer >= 0 -> integer
      _other -> default
    end
  end

  defp non_negative_integer(_value, default), do: default

  defp schedules_for(schedules, owner_type, owner_id) do
    Enum.filter(schedules, &(&1.owner_type == owner_type and &1.owner_id == owner_id))
  end

  defp input_summary(input) do
    schedules = Map.get(input, :schedules, [])

    %{
      session_templates: length(Map.get(input, :session_templates, [])),
      session_slots: length(Map.get(input, :session_slots, [])),
      direct_goals: length(Map.get(input, :direct_goals, [])),
      schedules: length(schedules),
      session_template_schedules: count_schedules(schedules, :session_template),
      direct_goal_schedules: count_schedules(schedules, :direct_goal),
      journal_events: length(Map.get(input, :journal_events, [])),
      session_occurrences: length(Map.get(input, :session_occurrences, [])),
      items: length(Map.get(input, :items, [])),
      pool_memberships: length(Map.get(input, :pool_memberships, [])),
      environments: length(Map.get(input, :environments, []))
    }
  end

  defp count_schedules(schedules, owner_type) do
    Enum.count(schedules, &(&1.owner_type == owner_type))
  end

  defp in_date_range?(date, starts_on, nil), do: Date.compare(date, starts_on) != :lt

  defp in_date_range?(date, starts_on, ends_on) do
    Date.compare(date, starts_on) != :lt and Date.compare(date, ends_on) != :gt
  end

  defp weekday(date), do: Map.fetch!(@weekdays, Date.day_of_week(date))

  defp explanations([]), do: ["No projected work is scheduled for this date."]

  defp explanations(projected_work) do
    Enum.map(projected_work, & &1.explanation)
  end
end
