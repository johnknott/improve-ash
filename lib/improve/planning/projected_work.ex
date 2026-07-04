defmodule Improve.Planning.ProjectedWork do
  @moduledoc """
  Value constructors for projected work returned by the pure planner.

  Projection answers "what should appear for this date?" without mutating
  history. A projected work item is intentionally broader than a session
  occurrence: it can represent a projected session or a track target.

  Common fields:

  - `:kind` is `:session` or `:track`.
  - `:status` is one of `:planned`, `:started`, `:partial`, `:completed`,
    `:missed`, `:skipped`, or `:on_hold`.
  - `:planned_for` is the date the work belongs to.
  - `:owner_type` and `:owner_id` identify the authored definition.
  - `:title` is display-ready enough for diagnostics, AI tools, and tests.
  - `:payload` contains kind-specific projected data.
  """

  @statuses [
    :planned,
    :started,
    :partial,
    :completed,
    :missed,
    :skipped,
    :on_hold
  ]

  def session(occurrence, opts \\ []) do
    status = status!(Keyword.get(opts, :status, :planned))

    payload =
      %{
        session_occurrence: occurrence,
        recommendations: occurrence.recommendations,
        session_state: Map.get(occurrence, :session_state, %{})
      }
      |> maybe_put(:time_off_window, Keyword.get(opts, :time_off_window))

    %{
      kind: :session,
      status: status,
      plan_id: occurrence.plan_id,
      planned_for: occurrence.planned_for,
      owner_type: :session_template,
      owner_id: occurrence.session_template_id,
      title: occurrence.session_template_name,
      payload: payload,
      explanation:
        Keyword.get(
          opts,
          :explanation,
          "Projected #{occurrence.session_template_name} from its schedule and deterministic slot recommendations."
        )
    }
  end

  def track(track, opts) do
    planned_for = Keyword.fetch!(opts, :planned_for)
    status = status!(Keyword.get(opts, :status, :planned))

    payload =
      %{
        track_id: track.id,
        track_key: track.key,
        event_type_id: track.event_type_id,
        target: track.target,
        completion_policy: track.completion_policy,
        missed_policy: track.missed_policy,
        completed_event_ids: Keyword.get(opts, :completed_event_ids, [])
      }
      |> maybe_put(:target_progress, Keyword.get(opts, :target_progress))
      |> maybe_put(:time_off_window, Keyword.get(opts, :time_off_window))

    %{
      kind: :track,
      status: status,
      plan_id: track.plan_id,
      planned_for: planned_for,
      owner_type: :track,
      owner_id: track.id,
      title: track.name,
      payload: payload,
      explanation:
        Keyword.get(
          opts,
          :explanation,
          "Projected #{track.name} from its track schedule."
        )
    }
  end

  defp status!(status) when status in @statuses, do: status

  defp status!(status) do
    raise ArgumentError, "Unsupported projected work status #{inspect(status)}."
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
