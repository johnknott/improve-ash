defmodule Improve.Planning.Projector do
  @moduledoc """
  Pure projection of planned work for explicit dates and records.
  """

  alias Improve.Planning.ProjectedWork
  alias Improve.Planning.Recommender
  alias Improve.Planning.Schedules

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

  defp explanations([]), do: ["No projected work is scheduled for this date."]

  defp explanations(projected_work) do
    Enum.map(projected_work, & &1.explanation)
  end
end
