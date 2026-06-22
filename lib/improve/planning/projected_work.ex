defmodule Improve.Planning.ProjectedWork do
  @moduledoc """
  Value constructors for projected work returned by the pure planner.

  Projection answers "what should appear for this date?" without mutating
  history. A projected work item is intentionally broader than a session
  occurrence: it can represent a projected session or a direct goal target.

  Common fields:

  - `:kind` is `:session` or `:direct_goal`.
  - `:status` is one of `:planned`, `:completed`, `:missed`, `:skipped`, or
    `:partially_completed`.
  - `:planned_for` is the date the work belongs to.
  - `:owner_type` and `:owner_id` identify the authored definition.
  - `:title` is display-ready enough for diagnostics, AI tools, and tests.
  - `:payload` contains kind-specific projected data.
  """

  @statuses [:planned, :completed, :missed, :skipped, :partially_completed]

  def session(occurrence, opts \\ []) do
    status = status!(Keyword.get(opts, :status, :planned))

    %{
      kind: :session,
      status: status,
      plan_id: occurrence.plan_id,
      planned_for: occurrence.planned_for,
      owner_type: :session_template,
      owner_id: occurrence.session_template_id,
      title: occurrence.session_template_name,
      payload: %{
        session_occurrence: occurrence,
        recommendations: occurrence.recommendations
      },
      explanation:
        Keyword.get(
          opts,
          :explanation,
          "Projected #{occurrence.session_template_name} from its schedule and deterministic slot recommendations."
        )
    }
  end

  def direct_goal(goal, opts) do
    planned_for = Keyword.fetch!(opts, :planned_for)
    status = status!(Keyword.get(opts, :status, :planned))

    %{
      kind: :direct_goal,
      status: status,
      plan_id: goal.plan_id,
      planned_for: planned_for,
      owner_type: :direct_goal,
      owner_id: goal.id,
      title: goal.name,
      payload: %{
        direct_goal_id: goal.id,
        direct_goal_key: goal.key,
        event_type_id: goal.event_type_id,
        target: goal.target,
        completion_policy: goal.completion_policy,
        missed_policy: goal.missed_policy,
        completed_event_ids: Keyword.get(opts, :completed_event_ids, [])
      },
      explanation:
        Keyword.get(
          opts,
          :explanation,
          "Projected #{goal.name} from its direct goal schedule."
        )
    }
  end

  defp status!(status) when status in @statuses, do: status

  defp status!(status) do
    raise ArgumentError, "Unsupported projected work status #{inspect(status)}."
  end
end
