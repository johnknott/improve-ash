defmodule Improve.Planning.Projector do
  @moduledoc """
  Pure projection of planned work for explicit dates and records.
  """

  alias Improve.Planning.EffectiveTarget
  alias Improve.Planning.ProjectedWork
  alias Improve.Planning.Recommender
  alias Improve.Planning.Schedules
  alias Improve.Planning.Targets

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
          time_off_window: occurrence.session_state.time_off_window,
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
    time_off_window = fully_off_window(input, date)
    decision_input = Map.put(input, :schedule_owner_name, template.name)

    cond do
      not in_date_range?(date, plan.starts_on, plan.ends_on) ->
        {:ok, nil}

      schedules == [] ->
        {:ok, nil}

      true ->
        case schedule_decisions(schedules, date, decision_input) do
          {:ok, true, diagnostics} ->
            cadence = Schedules.describe(List.first(schedules))
            {:ok, occurrence_projection(template, input, time_off_window, cadence), diagnostics}

          {:ok, false, diagnostics} ->
            {:ok, nil, diagnostics}

          {:error, diagnostic} ->
            {:error, diagnostic}
        end
    end
  end

  defp track_projection(track, input) do
    date = Map.fetch!(input, :date)
    plan = Map.fetch!(input, :plan)
    schedules = schedules_for(input.schedules, :track, track.id)
    time_off_window = fully_off_window(input, date)
    decision_input = Map.put(input, :schedule_owner_name, track.name)

    cond do
      not in_date_range?(date, plan.starts_on, plan.ends_on) ->
        {:ok, nil}

      schedules == [] ->
        {:ok, nil}

      true ->
        target_diagnostics = Targets.diagnostics(track)

        case schedule_decisions(schedules, date, decision_input) do
          {:ok, true, diagnostics} ->
            cadence = Schedules.describe(List.first(schedules))
            {work, completion_diagnostics} = track_work(track, input, time_off_window, cadence)

            {:ok, work, target_diagnostics ++ diagnostics ++ completion_diagnostics}

          {:ok, false, diagnostics} ->
            {:ok, nil, target_diagnostics ++ diagnostics}

          {:error, diagnostic} ->
            {:error, diagnostic}
        end
    end
  end

  defp occurrence_projection(template, input, time_off_window, cadence) do
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

    {status, session_state} = session_status(template, input, recommendations, time_off_window)

    %{
      plan_id: input.plan.id,
      session_template_id: template.id,
      session_template_name: template.name,
      planned_for: input.date,
      recommendations: recommendations,
      projected_status: status,
      projected_explanation: session_explanation(status, session_state, cadence),
      session_state: session_state
    }
  end

  defp session_status(template, input, recommendations, time_off_window) do
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

    status =
      if status == :planned and time_off_window do
        :on_hold
      else
        status
      end

    {status,
     %{
       session_occurrence_id: occurrence && occurrence.id,
       occurrence_status: occurrence && occurrence.status,
       slot_results_total: total,
       slot_results_logged: logged,
       slot_results_remaining: max(total - logged, 0),
       progress_label: progress_label(logged, total),
       recommended_slot_results: recommended_slot_results(recommendations),
       time_off_window: time_off_payload(time_off_window)
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

  # Explanations are UI copy: they sit under the card title, so they carry
  # schedule cadence and state in product language, never engine mechanics.
  defp session_explanation(:planned, _state, cadence) do
    cadence || "Planned for today."
  end

  defp session_explanation(:started, state, _cadence) do
    case state.progress_label do
      nil -> "In progress."
      label -> "In progress — #{label}."
    end
  end

  defp session_explanation(:partial, state, _cadence) do
    "Partly done — #{state.progress_label}."
  end

  defp session_explanation(:completed, state, _cadence) do
    case state.progress_label do
      nil -> "Completed."
      label -> "Completed — #{label}."
    end
  end

  defp session_explanation(:skipped, _state, _cadence) do
    "Skipped for the day."
  end

  defp session_explanation(:missed, _state, _cadence) do
    "Missed — the day passed without this session."
  end

  defp session_explanation(:on_hold, %{time_off_window: time_off_window}, _cadence) do
    "On hold — #{time_off_label(time_off_window)}."
  end

  defp track_work(track, input, time_off_window, cadence) do
    effective_target = effective_target_for(track, input)
    eval_track = %{track | target: EffectiveTarget.target_for_completion(effective_target)}

    {:ok, target_completion, diagnostics} = Targets.completion(eval_track, input)
    completed_events = Map.get(target_completion, :completed_events, [])
    skip_event = skip_event_for(track, input)

    status =
      track_status(
        input.date,
        Map.get(input, :as_of_date, input.date),
        Map.fetch!(target_completion, :status),
        time_off_window,
        skip_event
      )

    explanation =
      if status == :skipped do
        skip_explanation(skip_event)
      else
        track_explanation(status, time_off_window, cadence)
      end

    ProjectedWork.track(track,
      planned_for: input.date,
      status: status,
      completed_event_ids: Enum.map(completed_events, & &1.id),
      target_progress: Map.get(target_completion, :progress),
      effective_target: effective_target,
      time_off_window: time_off_payload(time_off_window),
      explanation: explanation
    )
    |> then(&{&1, diagnostics})
  end

  defp skip_event_for(track, input) do
    timezone = Map.get(input, :timezone) || Improve.Planning.LocalDate.default_timezone()

    input
    |> Map.get(:journal_events, [])
    |> Enum.find(fn event ->
      event.track_id == track.id and event.status == :skipped and
        Date.compare(
          Improve.Planning.LocalDate.to_date(event.effective_at, timezone),
          input.date
        ) == :eq
    end)
  end

  defp skip_explanation(skip_event) do
    case skip_event && skip_event.note do
      nil -> "Skipped for the day."
      reason -> "Skipped — #{reason}."
    end
  end

  defp effective_target_for(track, input) do
    base = EffectiveTarget.from_authored(track.target)

    case Map.get(input, :derived_adjustments) do
      nil ->
        base

      adjustments when is_map(adjustments) ->
        case Map.get(adjustments, track.id) do
          nil -> base
          adjustment -> apply_derived_adjustment(base, adjustment)
        end

      _ ->
        base
    end
  end

  defp apply_derived_adjustment(effective_target, adjustment) do
    EffectiveTarget.adjust(
      effective_target,
      Map.get(adjustment, :values, %{}),
      source: Map.get(adjustment, :source),
      reason: Map.get(adjustment, :reason)
    )
  end

  # A real completion always wins over a skip logged the same day.
  defp track_status(_date, _as_of_date, :completed, _time_off_window, _skip_event), do: :completed

  defp track_status(date, as_of_date, :incomplete, time_off_window, skip_event) do
    cond do
      skip_event ->
        :skipped

      time_off_window ->
        :on_hold

      Date.compare(date, as_of_date) == :lt ->
        :missed

      true ->
        :planned
    end
  end

  defp track_explanation(:completed, _time_off_window, _cadence) do
    "Done for today."
  end

  defp track_explanation(:missed, _time_off_window, _cadence) do
    "Missed — no entry for this day."
  end

  defp track_explanation(:planned, _time_off_window, cadence) do
    cadence || "Planned for today."
  end

  defp track_explanation(:on_hold, time_off_window, _cadence) do
    "On hold — #{time_off_label(time_off_window)}."
  end

  defp time_off_label(nil), do: "time off"

  defp time_off_label(window) do
    time_off_value(window, :reason) ||
      (time_off_value(window, :key) || "time off")
      |> to_string()
      |> String.replace("_", " ")
  end

  defp schedule_decisions(schedules, date, input) do
    Enum.reduce_while(schedules, {:ok, false, []}, &schedule_decision(&1, date, input, &2))
  end

  defp schedule_decision(schedule, date, input, {:ok, matched?, diagnostics}) do
    if not in_date_range?(date, schedule.starts_on, schedule.ends_on) do
      {:cont, {:ok, matched?, diagnostics}}
    else
      case Schedules.decide(schedule, date, input) do
        {:ok, true, new_diagnostics} -> {:halt, {:ok, true, diagnostics ++ new_diagnostics}}
        {:ok, false, new_diagnostics} -> {:cont, {:ok, matched?, diagnostics ++ new_diagnostics}}
        {:error, diagnostic} -> {:halt, {:error, diagnostic}}
      end
    end
  end

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
      time_off_windows: length(Map.get(input, :time_off_windows, [])),
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

  defp fully_off_window(input, date) do
    input
    |> Map.get(:time_off_windows, [])
    |> Enum.filter(&(time_off_value(&1, :availability) in [:fully_off, "fully_off"]))
    |> Enum.filter(
      &in_date_range?(date, time_off_value(&1, :starts_on), time_off_value(&1, :ends_on))
    )
    |> Enum.sort_by(&{time_off_value(&1, :starts_on), time_off_key(&1)})
    |> List.first()
  end

  defp time_off_payload(nil), do: nil

  defp time_off_payload(window) do
    %{
      id: time_off_value(window, :id),
      key: time_off_value(window, :key),
      kind: time_off_value(window, :kind),
      reason: time_off_value(window, :reason),
      starts_on: time_off_value(window, :starts_on),
      ends_on: time_off_value(window, :ends_on),
      availability: time_off_value(window, :availability)
    }
  end

  defp time_off_key(window), do: time_off_value(window, :key) || "time off"

  defp time_off_value(window, key) do
    Map.get(window, key) || Map.get(window, to_string(key))
  end

  defp explanations([]), do: ["No projected work is scheduled for this date."]

  defp explanations(projected_work) do
    Enum.map(projected_work, & &1.explanation)
  end
end
