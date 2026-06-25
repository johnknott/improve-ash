defmodule Improve.Bundles.Marathon.CommittedPlanEdits do
  @moduledoc """
  Approval-required adaptation proposals for durable plan edits.

  This module only describes possible edits. It does not mutate plan structure;
  acceptance and persistence belong to a later core action.
  """

  @doc """
  Returns committed plan-edit proposals implied by adaptation input.
  """
  def proposals(input) when is_map(input) do
    []
    |> maybe_add(illness_extension(input))
    |> maybe_add(injury_extension(input))
    |> maybe_add(holiday_gap_proposal(input))
  end

  defp illness_extension(input) do
    if recent_fever_illness?(input) do
      %{
        kind: :extend_plan,
        requires_approval: true,
        effect: :committed,
        proposed_edit: %{action: :extend_plan, weeks: 1},
        text: "Illness may delay race readiness; consider extending the plan by 1 week."
      }
    end
  end

  defp injury_extension(input) do
    case active_injury(input) do
      nil ->
        nil

      injury ->
        weeks = injury_extension_weeks(injury)

        %{
          kind: :extend_plan,
          requires_approval: true,
          effect: :committed,
          proposed_edit: %{action: :extend_plan, weeks: weeks},
          text:
            "Injury may delay race readiness; consider extending the plan by #{weeks} week#{plural(weeks)}."
        }
    end
  end

  defp holiday_gap_proposal(input) do
    date = Map.fetch!(input, :date)

    case ended_fully_off_window(input, date) do
      nil ->
        nil

      window ->
        gap_weeks =
          max(ceil(Date.diff(map_value(window, :ends_on), map_value(window, :starts_on)) / 7), 1)

        if movable_deadline?(input) do
          %{
            kind: :extend_plan,
            requires_approval: true,
            effect: :committed,
            proposed_edit: %{action: :extend_plan, weeks: gap_weeks},
            text:
              "Absorb the time-off gap by extending the plan by #{gap_weeks} week#{plural(gap_weeks)}."
          }
        else
          %{
            kind: :adjust_goal,
            requires_approval: true,
            effect: :committed,
            proposed_edit: %{action: :adjust_goal, reason: :fixed_deadline_after_time_off},
            text:
              "The race date is fixed; consider adjusting the goal or compressing the taper after time off."
          }
        end
    end
  end

  defp maybe_add(proposals, nil), do: proposals
  defp maybe_add(proposals, proposal), do: proposals ++ [proposal]

  defp recent_fever_illness?(input) do
    date = Map.fetch!(input, :date)

    input
    |> life_events()
    |> Enum.any?(fn event ->
      (event_type(event) == :illness and fever?(event) and
         event_to(event)) && Date.diff(date, event_to(event)) in 0..1
    end)
  end

  defp active_injury(input) do
    date = Map.fetch!(input, :date)

    input
    |> life_events()
    |> Enum.find(fn event ->
      event_type(event) == :injury and event_active_on?(event, date)
    end)
  end

  defp ended_fully_off_window(input, date) do
    input
    |> Map.get(:time_off_windows, [])
    |> Enum.find(fn window ->
      map_value(window, :availability) in [:fully_off, "fully_off"] and
        Date.diff(date, map_value(window, :ends_on)) == 1
    end)
  end

  defp movable_deadline?(input) do
    input
    |> Map.get(:plan_skeleton, %{})
    |> map_value(:deadline, %{})
    |> map_value(:movable?, false)
  end

  defp injury_extension_weeks(injury) do
    severity = event_value(injury, :severity) || payload_value(injury, :severity) || 1

    if severity >= 2, do: 2, else: 1
  end

  defp life_events(input), do: Map.get(input, :life_events, [])

  defp fever?(event) do
    event_value(event, :symptoms) in [:fever, "fever"] or
      payload_value(event, :symptoms) in [:fever, "fever"]
  end

  defp event_active_on?(event, date) do
    starts_on = event_from(event) || date
    ends_on = event_to(event)

    Date.compare(date, starts_on) != :lt and
      (is_nil(ends_on) or Date.compare(date, ends_on) != :gt)
  end

  defp event_from(event), do: event_value(event, :from) || event_value(event, :starts_on)
  defp event_to(event), do: event_value(event, :to) || event_value(event, :ends_on)

  defp event_type(event) do
    event_value(event, :type) || payload_value(event, :type) ||
      event_value(event, :event_type_key)
  end

  defp payload_value(event, key) do
    event
    |> event_value(:payload, %{})
    |> map_value(key)
  end

  defp event_value(event, key, default \\ nil), do: map_value(event, key, default)

  defp map_value(map, key, default \\ nil)

  defp map_value(map, key, default) when is_map(map) do
    Map.get(map, key, Map.get(map, to_string(key), default))
  end

  defp map_value(_value, _key, default), do: default

  defp plural(1), do: ""
  defp plural(_count), do: "s"
end
