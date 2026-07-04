defmodule Improve.App.Review do
  @moduledoc """
  Deterministic plan review for product stories and future UI/API flows.

  Two shapes:
  - **daily**: narrates today — what adapted and why, nothing durable.
  - **weekly**: durable proposals, trends, drift detection, what was
    deliberately not carried forward. Both deterministic; LLM narration
    on top is a later, optional layer.
  """

  alias Improve.App.DriftRule
  alias Improve.Journal
  alias Improve.Plans

  @drift_lookback_days 7
  @drift_threshold 5

  def review!(plan, opts) do
    shape = Keyword.get(opts, :shape, :daily)

    case shape do
      :daily -> daily_review!(plan, opts)
      :weekly -> weekly_review!(plan, opts)
    end
  end

  # --- Daily Review ---

  defp daily_review!(plan, opts) do
    actor = Keyword.fetch!(opts, :actor)
    on = Keyword.fetch!(opts, :on)
    timezone = Map.get(actor, :timezone) || "Etc/UTC"

    projection = Plans.project_today!(plan, actor: actor, date: on)
    journal_limit = Keyword.get(opts, :journal_limit, 20)
    journal_events = Journal.read_journal!(plan, actor: actor, limit: journal_limit * 3)

    recent_events =
      journal_events
      |> Enum.filter(&active_event?/1)
      |> Enum.filter(&event_on_or_before?(&1, on, timezone))
      |> Enum.take(-journal_limit)

    completed = Enum.filter(projection.projected_work, &(&1.status == :completed))

    still_to_do =
      Enum.filter(projection.projected_work, &(&1.status in [:planned, :started, :partial]))

    missed_or_skipped =
      Enum.filter(projection.projected_work, &(&1.status in [:missed, :skipped]))

    adaptations = extract_adaptations(projection)

    %{
      shape: :daily,
      plan_id: projection.plan_id,
      reviewed_on: on,
      observations:
        daily_observations(
          projection,
          recent_events,
          completed,
          still_to_do,
          missed_or_skipped,
          adaptations
        ),
      adaptations: adaptations,
      suggested_changes:
        daily_suggested_changes(
          projection,
          recent_events,
          completed,
          still_to_do,
          missed_or_skipped
        ),
      reasons: reasons(projection, recent_events, still_to_do, missed_or_skipped)
    }
  end

  # --- Weekly Review ---

  defp weekly_review!(plan, opts) do
    actor = Keyword.fetch!(opts, :actor)
    on = Keyword.fetch!(opts, :on)
    timezone = Map.get(actor, :timezone) || "Etc/UTC"

    summary = Plans.summarize_plan!(plan, actor: actor)
    projection = Plans.project_today!(plan, actor: actor, date: on)
    journal_limit = Keyword.get(opts, :journal_limit, 40)
    journal_events = Journal.read_journal!(plan, actor: actor, limit: journal_limit * 3)

    recent_events =
      journal_events
      |> Enum.filter(&active_event?/1)
      |> Enum.filter(&event_on_or_before?(&1, on, timezone))
      |> Enum.take(-journal_limit)

    completed = Enum.filter(projection.projected_work, &(&1.status == :completed))

    still_to_do =
      Enum.filter(projection.projected_work, &(&1.status in [:planned, :started, :partial]))

    missed_or_skipped =
      Enum.filter(projection.projected_work, &(&1.status in [:missed, :skipped]))

    pending_proposals = fetch_pending_proposals(plan, actor)
    drift_proposals = detect_drift(plan, on, actor, opts)
    adaptations = extract_adaptations(projection)

    %{
      shape: :weekly,
      plan_id: projection.plan_id,
      reviewed_on: on,
      observations:
        weekly_observations(
          summary,
          projection,
          recent_events,
          completed,
          still_to_do,
          missed_or_skipped,
          pending_proposals,
          adaptations
        ),
      adaptations: adaptations,
      pending_proposals: pending_proposals,
      drift_proposals: drift_proposals,
      suggested_changes:
        weekly_suggested_changes(
          projection,
          recent_events,
          completed,
          still_to_do,
          missed_or_skipped,
          pending_proposals,
          drift_proposals
        ),
      reasons: reasons(projection, recent_events, still_to_do, missed_or_skipped)
    }
  end

  # --- Adaptation extraction ---

  defp extract_adaptations(projection) do
    evaluator_output = Map.get(projection, :evaluator_output, %{}) || %{}
    adjustments = Map.get(evaluator_output, :derived_target_adjustments, %{}) || %{}

    Enum.map(adjustments, fn {track_id, adjustment} ->
      %{
        track_id: to_string(track_id),
        source: Map.get(adjustment, :source) || Map.get(adjustment, "source"),
        reason: Map.get(adjustment, :reason) || Map.get(adjustment, "reason"),
        values: Map.get(adjustment, :values) || Map.get(adjustment, "values") || %{}
      }
    end)
  end

  # --- Drift detection ---

  defp detect_drift(plan, on, actor, opts) do
    lookback = Keyword.get(opts, :drift_lookback_days, @drift_lookback_days)
    threshold = Keyword.get(opts, :drift_threshold, @drift_threshold)

    dates = Date.range(Date.add(on, -(lookback - 1)), on) |> Enum.to_list()

    case Plans.project_dates(plan, dates, actor: actor) do
      {:ok, projections} ->
        records = DriftRule.records_from_projections(projections)
        DriftRule.detect(records, threshold: threshold)

      {:error, _} ->
        []
    end
  end

  # --- Proposals ---

  defp fetch_pending_proposals(plan, actor) do
    case Plans.list_proposals(
           actor: actor,
           query: [filter: [plan_id: plan.id, status: :proposed]]
         ) do
      {:ok, proposals} -> proposals
      _ -> []
    end
  end

  # --- Daily Observations ---

  defp daily_observations(
         projection,
         recent_events,
         completed,
         still_to_do,
         missed_or_skipped,
         adaptations
       ) do
    base = [
      %{
        topic: :today,
        text:
          "On #{Date.to_iso8601(projection.date)}, #{length(completed)} work item(s) completed, #{length(still_to_do)} still planned.",
        data: %{
          completed: length(completed),
          still_to_do: length(still_to_do),
          missed_or_skipped: length(missed_or_skipped)
        }
      },
      %{
        topic: :history,
        text: "#{length(recent_events)} recent journal event(s) considered.",
        data: %{active_events: length(recent_events)}
      }
    ]

    adaptation_obs =
      if adaptations != [] do
        [
          %{
            topic: :adaptations,
            text: "#{length(adaptations)} track(s) have derived adjustments active today.",
            data: %{
              adaptations:
                Enum.map(adaptations, fn a ->
                  %{track_id: a.track_id, source: a.source, reason: a.reason}
                end)
            }
          }
        ]
      else
        []
      end

    base ++ adaptation_obs ++ diagnostic_observations(projection)
  end

  # --- Weekly Observations ---

  defp weekly_observations(
         summary,
         projection,
         recent_events,
         completed,
         still_to_do,
         missed_or_skipped,
         pending_proposals,
         adaptations
       ) do
    base = [
      %{
        topic: :plan_shape,
        text:
          "Plan has #{summary.tracks} track(s), #{summary.session_templates} session(s), and #{summary.items} item(s).",
        data: %{
          tracks: summary.tracks,
          sessions: summary.session_templates,
          items: summary.items
        }
      },
      %{
        topic: :today,
        text:
          "On #{Date.to_iso8601(projection.date)}, #{length(completed)} work item(s) completed, #{length(still_to_do)} still planned.",
        data: %{
          completed: length(completed),
          still_to_do: length(still_to_do),
          missed_or_skipped: length(missed_or_skipped)
        }
      },
      %{
        topic: :history,
        text: "#{length(recent_events)} recent journal event(s) considered.",
        data: %{active_events: length(recent_events)}
      }
    ]

    proposal_obs =
      if pending_proposals != [] do
        [
          %{
            topic: :pending_proposals,
            text: "#{length(pending_proposals)} pending proposal(s) await review.",
            data: %{count: length(pending_proposals)}
          }
        ]
      else
        []
      end

    adaptation_obs =
      if adaptations != [] do
        [
          %{
            topic: :adaptations,
            text: "#{length(adaptations)} track(s) have derived adjustments active today.",
            data: %{
              adaptations:
                Enum.map(adaptations, fn a ->
                  %{track_id: a.track_id, source: a.source, reason: a.reason}
                end)
            }
          }
        ]
      else
        []
      end

    base ++ proposal_obs ++ adaptation_obs ++ diagnostic_observations(projection)
  end

  # --- Daily Suggested Changes ---

  defp daily_suggested_changes(
         projection,
         recent_events,
         completed,
         still_to_do,
         missed_or_skipped
       ) do
    []
    |> maybe_add(projection.diagnostics != [], %{
      change: :fix_authored_content,
      text: "Review plan diagnostics before changing future recommendations.",
      reason: "Diagnostics mean part of the authored plan cannot be projected cleanly yet."
    })
    |> maybe_add(recent_events == [], %{
      change: :keep_collecting_history,
      text: "Keep the plan unchanged until there is logged history to learn from.",
      reason: "A review with no journal history should not invent recommendation changes."
    })
    |> maybe_add(recent_events != [] and still_to_do != [] and completed == [], %{
      change: :check_todays_scope,
      text: "Check whether today's planned work is realistic.",
      reason: "There is history, but today's projection still has work waiting."
    })
    |> maybe_add(missed_or_skipped != [], %{
      change: :adjust_schedule_or_session,
      text: "Consider changing the schedule or session shape for missed or skipped work.",
      reason: "Missed or skipped work is a signal that the plan may not fit the current context."
    })
    |> maybe_add(recent_events != [] and projection.diagnostics == [], %{
      change: :tune_recommendations_from_history,
      text: "Use recent completed history to tune future recommendations.",
      reason: "The plan has real journal history and no projection diagnostics blocking review."
    })
  end

  # --- Weekly Suggested Changes ---

  defp weekly_suggested_changes(
         projection,
         recent_events,
         completed,
         still_to_do,
         missed_or_skipped,
         pending_proposals,
         drift_proposals
       ) do
    []
    |> maybe_add(projection.diagnostics != [], %{
      change: :fix_authored_content,
      text: "Review plan diagnostics before changing future recommendations.",
      reason: "Diagnostics mean part of the authored plan cannot be projected cleanly yet."
    })
    |> maybe_add(pending_proposals != [], %{
      change: :review_pending_proposals,
      text: "#{length(pending_proposals)} pending proposal(s) should be approved or dismissed.",
      reason: "Pending proposals represent evaluator suggestions that need human approval."
    })
    |> maybe_add(drift_proposals != [], %{
      change: :consider_rebaseline,
      text:
        "#{length(drift_proposals)} track(s) show persistent drift — consider rebasing the authored target.",
      reason:
        "Consecutive same-direction adjustments suggest the authored target no longer reflects reality."
    })
    |> maybe_add(recent_events == [], %{
      change: :keep_collecting_history,
      text: "Keep the plan unchanged until there is logged history to learn from.",
      reason: "A review with no journal history should not invent recommendation changes."
    })
    |> maybe_add(recent_events != [] and still_to_do != [] and completed == [], %{
      change: :check_todays_scope,
      text: "Check whether today's planned work is realistic.",
      reason: "There is history, but today's projection still has work waiting."
    })
    |> maybe_add(missed_or_skipped != [], %{
      change: :adjust_schedule_or_session,
      text: "Consider changing the schedule or session shape for missed or skipped work.",
      reason: "Missed or skipped work is a signal that the plan may not fit the current context."
    })
    |> maybe_add(recent_events != [] and projection.diagnostics == [], %{
      change: :tune_recommendations_from_history,
      text: "Use recent completed history to tune future recommendations.",
      reason: "The plan has real journal history and no projection diagnostics blocking review."
    })
  end

  # --- Shared helpers ---

  defp diagnostic_observations(%{diagnostics: []}), do: []

  defp diagnostic_observations(projection) do
    [
      %{
        topic: :diagnostics,
        text:
          "Projection returned #{length(projection.diagnostics)} diagnostic(s) that should be reviewed before tuning the plan.",
        data: %{diagnostics: Enum.map(projection.diagnostics, &diagnostic_summary/1)}
      }
    ]
  end

  defp reasons(projection, recent_events, still_to_do, missed_or_skipped) do
    [
      "Review is deterministic and read-only.",
      "#{length(recent_events)} active journal event(s) were considered.",
      "#{length(still_to_do)} projected work item(s) are still open for the review date.",
      "#{length(missed_or_skipped)} projected work item(s) are missed or skipped for the review date.",
      "#{length(projection.diagnostics)} projection diagnostic(s) were considered."
    ]
  end

  defp active_event?(event), do: event.status == :active

  defp event_on_or_before?(event, date, timezone) do
    Date.compare(Improve.Planning.LocalDate.to_date(event.effective_at, timezone), date) in [
      :lt,
      :eq
    ]
  end

  defp diagnostic_summary(diagnostic) do
    %{
      code: diagnostic.code,
      message: diagnostic.message,
      severity: diagnostic.severity
    }
  end

  defp maybe_add(changes, true, change), do: changes ++ [change]
  defp maybe_add(changes, false, _change), do: changes
end
