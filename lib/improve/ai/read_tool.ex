defmodule Improve.Ai.ReadTool do
  @moduledoc """
  Read-only Ash actions exposed as AshAI tools for the product spike.
  """

  use Ash.Resource,
    otp_app: :improve,
    domain: Improve.Ai

  alias Improve.Journal
  alias Improve.Plans

  actions do
    action :project_today, :map do
      description "Project planned work for a date without mutating history."

      argument :plan_id, :uuid, allow_nil?: false
      argument :date, :date, allow_nil?: false

      run fn input, context ->
        actor = actor!(context)

        input.arguments.plan_id
        |> Plans.project_today(actor: actor, date: input.arguments.date)
        |> map_ok(&projection_json/1)
      end
    end

    action :get_plan_summary, :map do
      description "Return authored content counts for a plan."

      argument :plan_id, :uuid, allow_nil?: false

      run fn input, context ->
        actor = actor!(context)
        Plans.summarize_plan(input.arguments.plan_id, actor: actor)
      end
    end

    action :get_recent_journal_events, :map do
      description "Return recent journal events for a plan."

      argument :plan_id, :uuid, allow_nil?: false
      argument :limit, :integer, allow_nil?: false, default: 10, constraints: [min: 1, max: 50]

      run fn input, context ->
        actor = actor!(context)
        limit = input.arguments.limit

        input.arguments.plan_id
        |> Journal.read_journal(actor: actor)
        |> map_ok(fn events ->
          %{
            plan_id: input.arguments.plan_id,
            events:
              events
              |> Enum.take(-limit)
              |> Enum.reverse()
              |> Enum.map(&event_json/1)
          }
        end)
      end
    end

    action :get_item_state, :map do
      description "Return derived state for an item."

      argument :item_id, :uuid, allow_nil?: false

      run fn input, context ->
        actor = actor!(context)

        input.arguments.item_id
        |> Journal.get_item_state(actor: actor)
        |> map_ok(&item_state_json/1)
      end
    end
  end

  defp actor!(%{actor: nil}) do
    raise "AshAI read tools require an actor."
  end

  defp actor!(%{actor: actor}), do: actor

  defp map_ok({:ok, value}, mapper), do: {:ok, mapper.(value)}
  defp map_ok({:error, error}, _mapper), do: {:error, error}

  defp projection_json(projection) do
    %{
      plan_id: projection.plan_id,
      date: Date.to_iso8601(projection.date),
      projected_session_occurrences:
        Enum.map(projection.projected_session_occurrences, &projected_occurrence_json/1),
      projected_work: Enum.map(projection.projected_work, &projected_work_json/1),
      diagnostics: projection.diagnostics,
      explanations: projection.explanations
    }
  end

  defp projected_work_json(%{kind: :session, payload: %{session_occurrence: occurrence}} = work) do
    %{
      kind: "session",
      status: Atom.to_string(work.status),
      planned_for: Date.to_iso8601(work.planned_for),
      owner_type: "session_template",
      owner_id: work.owner_id,
      title: work.title,
      explanation: work.explanation,
      session_occurrence: projected_occurrence_json(occurrence)
    }
  end

  defp projected_work_json(%{kind: :direct_goal, payload: payload} = work) do
    %{
      kind: "direct_goal",
      status: Atom.to_string(work.status),
      planned_for: Date.to_iso8601(work.planned_for),
      owner_type: "direct_goal",
      owner_id: work.owner_id,
      title: work.title,
      explanation: work.explanation,
      direct_goal: %{
        direct_goal_id: payload.direct_goal_id,
        direct_goal_key: payload.direct_goal_key,
        event_type_id: payload.event_type_id,
        target: payload.target,
        completion_policy: payload.completion_policy,
        missed_policy: payload.missed_policy,
        completed_event_ids: payload.completed_event_ids
      }
    }
  end

  defp projected_occurrence_json(occurrence) do
    %{
      plan_id: occurrence.plan_id,
      session_template_id: occurrence.session_template_id,
      session_template_name: occurrence.session_template_name,
      planned_for: Date.to_iso8601(occurrence.planned_for),
      recommendations: Enum.map(occurrence.recommendations, &recommendation_json/1)
    }
  end

  defp recommendation_json(recommendation) do
    %{
      session_slot_id: recommendation.session_slot_id,
      slot_key: recommendation.slot_key,
      slot_name: recommendation.slot_name,
      count: recommendation.count,
      recommended_items: Enum.map(recommendation.recommended_items, &recommended_item_json/1)
    }
  end

  defp recommended_item_json(item) do
    %{
      item_id: item.item_id,
      item_key: item.item_key,
      item_name: item.item_name,
      reason: Map.get(item, :reason)
    }
  end

  defp event_json(event) do
    %{
      id: event.id,
      event_type_id: event.event_type_id,
      summary: event.summary,
      status: event.status,
      quantity: decimal_string(event.quantity),
      unit: event.unit,
      effective_at: DateTime.to_iso8601(event.effective_at),
      recorded_at: DateTime.to_iso8601(event.recorded_at),
      replaces_event_instance_id: event.replaces_event_instance_id
    }
  end

  defp item_state_json(state) do
    %{
      item_id: state.item_id,
      starting_facts: stringify_values(state.starting_facts),
      calculated_state: stringify_values(state.calculated_state),
      active_effects: Enum.map(state.active_effects, &effect_json/1),
      warnings: state.warnings
    }
  end

  defp effect_json(effect) do
    %{
      id: effect.id,
      event_instance_id: effect.event_instance_id,
      effect_type: effect.effect_type,
      quantity: decimal_string(effect.quantity),
      unit: effect.unit,
      status: effect.status,
      replaces_item_effect_id: effect.replaces_item_effect_id
    }
  end

  defp stringify_values(map) do
    Map.new(map, fn {key, value} -> {key, stringify_value(value)} end)
  end

  defp stringify_value(%Decimal{} = value), do: Decimal.to_string(value)
  defp stringify_value(value), do: value

  defp decimal_string(nil), do: nil
  defp decimal_string(%Decimal{} = value), do: Decimal.to_string(value)
end
