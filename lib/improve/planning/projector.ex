defmodule Improve.Planning.Projector do
  @moduledoc """
  Pure projection of planned work for explicit dates and records.
  """

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

    {occurrences, diagnostics} =
      templates
      |> Enum.sort_by(& &1.key)
      |> Enum.reduce({[], []}, fn template, {occurrences, diagnostics} ->
        case template_projection(template, input) do
          {:ok, nil} ->
            {occurrences, diagnostics}

          {:ok, occurrence} ->
            {[occurrence | occurrences], diagnostics}

          {:error, diagnostic} ->
            {occurrences, [diagnostic | diagnostics]}
        end
      end)

    %{
      plan_id: plan.id,
      date: date,
      projected_session_occurrences: Enum.reverse(occurrences),
      diagnostics: Enum.reverse(diagnostics),
      explanations: explanations(occurrences)
    }
  end

  defp template_projection(template, input) do
    date = Map.fetch!(input, :date)
    plan = Map.fetch!(input, :plan)
    schedules = schedules_for(input.schedules, template.id)

    cond do
      not in_date_range?(date, plan.starts_on, plan.ends_on) ->
        {:ok, nil}

      schedules == [] ->
        {:ok, nil}

      true ->
        case Enum.reduce_while(schedules, {:ok, false}, &schedule_decision(&1, date, &2)) do
          {:ok, true} -> {:ok, occurrence_projection(template, input)}
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

  defp schedule_decision(schedule, date, {:ok, matched?}) do
    if not in_date_range?(date, schedule.starts_on, schedule.ends_on) do
      {:cont, {:ok, matched?}}
    else
      case schedule_applies?(schedule, date) do
        {:ok, true} -> {:halt, {:ok, true}}
        {:ok, false} -> {:cont, {:ok, matched?}}
        {:error, diagnostic} -> {:halt, {:error, diagnostic}}
      end
    end
  end

  defp schedule_applies?(%{kind: :every_day}, _date), do: {:ok, true}

  defp schedule_applies?(%{kind: :selected_weekdays, rules: rules}, date) do
    {:ok, weekday(date) in Map.get(rules, "weekdays", [])}
  end

  defp schedule_applies?(%{kind: :times_per_week, rules: rules}, date) do
    {:ok, weekday(date) in Map.get(rules, "allowed_weekdays", [])}
  end

  defp schedule_applies?(schedule, _date) do
    {:error,
     %{
       code: :unsupported_schedule_kind,
       message: "Schedule kind is not supported by the POC projector.",
       details: %{schedule_id: schedule.id, kind: schedule.kind}
     }}
  end

  defp schedules_for(schedules, template_id) do
    Enum.filter(schedules, &(&1.owner_type == :session_template and &1.owner_id == template_id))
  end

  defp in_date_range?(date, starts_on, nil), do: Date.compare(date, starts_on) != :lt

  defp in_date_range?(date, starts_on, ends_on) do
    Date.compare(date, starts_on) != :lt and Date.compare(date, ends_on) != :gt
  end

  defp weekday(date), do: Map.fetch!(@weekdays, Date.day_of_week(date))

  defp explanations([]), do: ["No session templates are scheduled for this date."]

  defp explanations(occurrences) do
    Enum.map(occurrences, fn occurrence ->
      "Projected #{occurrence.session_template_name} from its schedule and deterministic slot recommendations."
    end)
  end
end
