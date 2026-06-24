defmodule Improve.App.Review do
  @moduledoc """
  Deterministic plan review for product stories and future UI/API flows.
  """

  alias Improve.Journal
  alias Improve.Plans

  def review!(plan, opts) do
    actor = Keyword.fetch!(opts, :actor)
    on = Keyword.fetch!(opts, :on)

    summary = Plans.summarize_plan!(plan, actor: actor)
    projection = Plans.project_today!(plan, actor: actor, date: on)
    journal_events = Journal.read_journal!(plan, actor: actor)

    recent_events =
      journal_events
      |> Enum.filter(&active_event?/1)
      |> Enum.filter(&event_on_or_before?(&1, on))
      |> Enum.take(-Keyword.get(opts, :journal_limit, 20))

    completed = Enum.filter(projection.projected_work, &(&1.status == :completed))

    still_to_do =
      Enum.filter(projection.projected_work, &(&1.status in [:planned, :started, :partial]))

    missed_or_skipped =
      Enum.filter(projection.projected_work, &(&1.status in [:missed, :skipped]))

    %{
      plan_id: projection.plan_id,
      reviewed_on: on,
      observations:
        observations(
          summary,
          projection,
          recent_events,
          completed,
          still_to_do,
          missed_or_skipped
        ),
      suggested_changes:
        suggested_changes(projection, recent_events, completed, still_to_do, missed_or_skipped),
      reasons: reasons(projection, recent_events, still_to_do, missed_or_skipped)
    }
  end

  defp observations(summary, projection, recent_events, completed, still_to_do, missed_or_skipped) do
    [
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
          "On #{Date.to_iso8601(projection.date)}, #{length(completed)} work item(s) are completed and #{length(still_to_do)} are still planned.",
        data: %{
          completed: length(completed),
          still_to_do: length(still_to_do),
          missed_or_skipped: length(missed_or_skipped)
        }
      },
      %{
        topic: :history,
        text: "Recent journal history contains #{length(recent_events)} active event(s).",
        data: %{active_events: length(recent_events)}
      }
    ] ++ diagnostic_observations(projection)
  end

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

  defp suggested_changes(projection, recent_events, completed, still_to_do, missed_or_skipped) do
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

  defp event_on_or_before?(event, date) do
    Date.compare(DateTime.to_date(event.effective_at), date) in [:lt, :eq]
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
