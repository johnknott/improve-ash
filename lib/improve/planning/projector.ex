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

    {track_work, track_diagnostics} =
      project_entries(Map.get(input, :tracks, []), &track_projection(&1, input))

    occurrences = Enum.reverse(occurrences)
    track_work = Enum.reverse(track_work)

    projected_work =
      Enum.map(occurrences, fn occurrence ->
        ProjectedWork.session(occurrence,
          status: occurrence.projected_status,
          explanation: occurrence.projected_explanation
        )
      end) ++ track_work

    %{
      plan_id: plan.id,
      date: date,
      projected_session_occurrences: occurrences,
      projected_work: projected_work,
      input_summary: input_summary(input),
      diagnostics: Enum.reverse(session_diagnostics) ++ Enum.reverse(track_diagnostics),
      explanations: explanations(projected_work)
    }
  end

  defp project_entries(entries, project_fun) do
    entries
    |> Enum.sort_by(& &1.key)
    |> Enum.reduce({[], []}, fn entry, {projections, diagnostics} ->
      case project_fun.(entry) do
        {:ok, nil} ->
          {projections, diagnostics}

        {:ok, nil, new_diagnostics} ->
          {projections, diagnostics ++ new_diagnostics}

        {:ok, projection} ->
          {[projection | projections], diagnostics}

        {:ok, projection, new_diagnostics} ->
          {[projection | projections], diagnostics ++ new_diagnostics}

        {:error, diagnostic} ->
          {projections, [diagnostic | diagnostics]}
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
        case schedule_decisions(schedules, date, input) do
          {:ok, true, diagnostics} -> {:ok, occurrence_projection(template, input), diagnostics}
          {:ok, false, diagnostics} -> {:ok, nil, diagnostics}
          {:error, diagnostic} -> {:error, diagnostic}
        end
    end
  end

  defp track_projection(track, input) do
    date = Map.fetch!(input, :date)
    plan = Map.fetch!(input, :plan)
    schedules = schedules_for(input.schedules, :track, track.id)

    cond do
      not in_date_range?(date, plan.starts_on, plan.ends_on) ->
        {:ok, nil}

      schedules == [] ->
        {:ok, nil}

      true ->
        target_diagnostics = track_target_diagnostics(track)

        case schedule_decisions(schedules, date, input) do
          {:ok, true, diagnostics} ->
            {:ok, track_work(track, input), target_diagnostics ++ diagnostics}

          {:ok, false, diagnostics} ->
            {:ok, nil, target_diagnostics ++ diagnostics}

          {:error, diagnostic} ->
            {:error, diagnostic}
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
              recent_item_ids: Map.get(input, :recent_item_ids, []),
              journal_events: Map.get(input, :journal_events, [])
            })
        }
      end)

    {status, session_state} = session_status(template, input, recommendations)

    %{
      plan_id: input.plan.id,
      session_template_id: template.id,
      session_template_name: template.name,
      planned_for: input.date,
      recommendations: recommendations,
      projected_status: status,
      projected_explanation: session_explanation(template, status, session_state),
      session_state: session_state
    }
  end

  defp session_status(template, input, recommendations) do
    occurrence = matching_session_occurrence(template, input)
    slot_results = slot_results_for(occurrence, input)
    total = length(slot_results)
    logged = Enum.count(slot_results, &slot_logged?/1)

    status =
      cond do
        occurrence == nil ->
          :planned

        occurrence.status in [:completed, :missed, :skipped] ->
          occurrence.status

        total > 0 and logged == total ->
          :completed

        logged > 0 ->
          :partial

        occurrence.status == :started ->
          :started

        true ->
          :planned
      end

    {status,
     %{
       session_occurrence_id: occurrence && occurrence.id,
       occurrence_status: occurrence && occurrence.status,
       slot_results_total: total,
       slot_results_logged: logged,
       slot_results_remaining: max(total - logged, 0),
       progress_label: progress_label(logged, total),
       recommended_slot_results: recommended_slot_results(recommendations)
     }}
  end

  defp matching_session_occurrence(template, input) do
    input
    |> Map.get(:session_occurrences, [])
    |> Enum.find(fn occurrence ->
      occurrence.session_template_id == template.id and occurrence.planned_for == input.date
    end)
  end

  defp slot_results_for(nil, _input), do: []

  defp slot_results_for(occurrence, input) do
    input
    |> Map.get(:slot_results, [])
    |> Enum.filter(&(&1.session_occurrence_id == occurrence.id))
  end

  defp slot_logged?(slot_result) do
    not is_nil(slot_result.event_instance_id) or slot_result.status in [:completed, :skipped]
  end

  defp progress_label(_logged, 0), do: nil
  defp progress_label(logged, total), do: "#{logged} of #{total} logged"

  defp recommended_slot_results(recommendations) do
    recommendations
    |> Enum.map(&length(&1.recommended_items))
    |> Enum.sum()
  end

  defp session_explanation(template, :planned, _state) do
    "Projected #{template.name} from its schedule and deterministic slot recommendations."
  end

  defp session_explanation(template, :started, _state) do
    "Projected #{template.name} as started from its session occurrence."
  end

  defp session_explanation(template, :partial, state) do
    "Projected #{template.name} as partial because #{state.progress_label}."
  end

  defp session_explanation(template, :completed, state) do
    if state.progress_label do
      "Projected #{template.name} as completed because #{state.progress_label}."
    else
      "Projected #{template.name} as completed from its session occurrence."
    end
  end

  defp session_explanation(template, :skipped, _state) do
    "Projected #{template.name} as skipped from its session occurrence."
  end

  defp session_explanation(template, :missed, _state) do
    "Projected #{template.name} as missed from its session occurrence."
  end

  defp track_work(track, input) do
    completed_events = completed_track_events(track, input)

    status =
      track_status(input.date, Map.get(input, :as_of_date, input.date), completed_events)

    ProjectedWork.track(track,
      planned_for: input.date,
      status: status,
      completed_event_ids: Enum.map(completed_events, & &1.id),
      explanation: track_explanation(track, status, completed_events)
    )
  end

  defp completed_track_events(track, input) do
    input
    |> Map.get(:journal_events, [])
    |> Enum.filter(fn event ->
      event.track_id == track.id and event.status == :active and
        Date.compare(DateTime.to_date(event.effective_at), input.date) == :eq
    end)
  end

  defp track_status(_date, _as_of_date, [_event | _events]), do: :completed

  defp track_status(date, as_of_date, []) do
    if Date.compare(date, as_of_date) == :lt do
      :missed
    else
      :planned
    end
  end

  defp track_explanation(track, :completed, events) do
    "Projected #{track.name} as completed from #{length(events)} linked journal event(s)."
  end

  defp track_explanation(track, :missed, _events) do
    "Projected #{track.name} as missed because the date has passed without a linked journal event."
  end

  defp track_explanation(track, :planned, _events) do
    "Projected #{track.name} from its track schedule."
  end

  defp track_target_diagnostics(%{target: nil} = track) do
    [
      %{
        code: :missing_track_target,
        severity: :warning,
        message:
          "Track has no target, so completion can only be inferred from linked journal events.",
        details: %{track_id: track.id, track_key: track.key}
      }
    ]
  end

  defp track_target_diagnostics(%{target: target} = track)
       when is_map(target) and map_size(target) == 0 do
    [
      %{
        code: :missing_track_target,
        severity: :warning,
        message:
          "Track has no target, so completion can only be inferred from linked journal events.",
        details: %{track_id: track.id, track_key: track.key}
      }
    ]
  end

  defp track_target_diagnostics(%{target: target} = track) when is_map(target) do
    case target_type(target) do
      nil ->
        []

      "fixed" ->
        []

      type when type in ["metric", "checklist", "period_total", "progression", "adaptive"] ->
        [
          %{
            code: :unsupported_track_target_type,
            severity: :info,
            message:
              "This track target type is recognized, but projection support is not implemented yet.",
            details: %{track_id: track.id, track_key: track.key, target_type: type}
          }
        ]

      type ->
        [
          %{
            code: :unknown_track_target_type,
            severity: :warning,
            message: "This track target type is not recognized.",
            details: %{track_id: track.id, track_key: track.key, target_type: type}
          }
        ]
    end
  end

  defp track_target_diagnostics(_track), do: []

  defp target_type(target) do
    case Map.get(target, "type") || Map.get(target, :type) do
      nil -> nil
      type when is_atom(type) -> Atom.to_string(type)
      type when is_binary(type) -> type
    end
  end

  defp schedule_decisions(schedules, date, input) do
    Enum.reduce_while(schedules, {:ok, false, []}, &schedule_decision(&1, date, input, &2))
  end

  defp schedule_decision(schedule, date, input, {:ok, matched?, diagnostics}) do
    if not in_date_range?(date, schedule.starts_on, schedule.ends_on) do
      {:cont, {:ok, matched?, diagnostics}}
    else
      case schedule_applies?(schedule, date, input) do
        {:ok, true, new_diagnostics} -> {:halt, {:ok, true, diagnostics ++ new_diagnostics}}
        {:ok, false, new_diagnostics} -> {:cont, {:ok, matched?, diagnostics ++ new_diagnostics}}
        {:error, diagnostic} -> {:halt, {:error, diagnostic}}
      end
    end
  end

  defp schedule_applies?(%{kind: :every_day}, _date, _input), do: {:ok, true, []}

  defp schedule_applies?(%{kind: :selected_weekdays, rules: rules}, date, _input) do
    {:ok, weekday(date) in Map.get(rules, "weekdays", []), []}
  end

  defp schedule_applies?(%{kind: :every_n_days, rules: rules} = schedule, date, _input) do
    interval_days = Map.get(rules, "interval_days", Map.get(rules, "days"))

    case parse_positive_integer(interval_days) do
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

  defp schedule_applies?(%{kind: :times_per_week} = schedule, date, input) do
    quota = quota_plan(schedule, date, input)
    {:ok, date in quota.due_dates, quota.diagnostics}
  end

  defp schedule_applies?(%{kind: kind} = schedule, _date, _input)
       when kind in [:after_completion, :custom, :every_n_weeks, :monthly] do
    {:ok, false,
     [
       %{
         code: :recognized_unsupported_schedule_kind,
         severity: :info,
         message:
           "This schedule kind is recognized, but projection support is not implemented yet.",
         details: %{schedule_id: schedule.id, kind: kind}
       }
     ]}
  end

  defp schedule_applies?(schedule, _date, _input) do
    {:error,
     %{
       code: :unsupported_schedule_kind,
       severity: :warning,
       message: "Schedule kind is not recognized by the projector.",
       details: %{schedule_id: schedule.id, kind: schedule.kind}
     }}
  end

  defp quota_plan(schedule, date, input) do
    rules = schedule.rules || %{}
    times = positive_integer(Map.get(rules, "times", Map.get(rules, "count", 1)), 1)
    minimum_gap_days = non_negative_integer(Map.get(rules, "minimum_gap_days", 0), 0)
    {allowed_weekdays, rule_diagnostics} = allowed_weekdays(schedule, rules)
    {week_start, week_end} = week_bounds(date)
    as_of_date = Map.get(input, :as_of_date, date)
    placement_start = quota_placement_start(date, as_of_date, week_start)

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
        {Map.values(@weekdays), []}

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
    input
    |> Map.get(:journal_events, [])
    |> Enum.filter(&(&1.track_id == owner_id and &1.status == :active))
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

  defp dates_through(start_date, end_date) do
    0..Date.diff(end_date, start_date)
    |> Enum.map(&Date.add(start_date, &1))
  end

  defp positive_integer(value, default), do: max(non_negative_integer(value, default), 1)

  defp parse_positive_integer(value) when is_integer(value) and value > 0, do: value

  defp parse_positive_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} when integer > 0 -> integer
      _other -> nil
    end
  end

  defp parse_positive_integer(_value), do: nil

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
      tracks: length(Map.get(input, :tracks, [])),
      schedules: length(schedules),
      session_template_schedules: count_schedules(schedules, :session_template),
      track_schedules: count_schedules(schedules, :track),
      journal_events: length(Map.get(input, :journal_events, [])),
      session_occurrences: length(Map.get(input, :session_occurrences, [])),
      slot_results: length(Map.get(input, :slot_results, [])),
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
