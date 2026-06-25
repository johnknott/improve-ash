defmodule Improve.Planning.Adaptation.Marathon do
  @moduledoc """
  Projection-time marathon adaptation evaluator.

  This evaluator only returns derived, no-write adaptation output. Durable plan
  edits such as extending a race plan are represented by a later committed
  proposal layer.
  """

  alias Improve.Planning.Adaptation.CommittedPlanEdits

  @low_reentry_load_km 5

  @doc """
  Evaluates marathon adaptation from explicit host input.
  """
  def evaluate(input) when is_map(input) do
    adaptation =
      input
      |> base_output()
      |> apply_missed_quality(input)
      |> apply_illness(input)
      |> apply_injury(input)
      |> apply_holiday_reentry(input)
      |> Map.put(:committed_proposals, CommittedPlanEdits.proposals(input))

    {:ok, %{marathon_adaptation: adaptation}, []}
  end

  defp base_output(input) do
    %{
      today: Enum.map(Map.get(input, :projected_work, []), &keep_work/1),
      proposals: [],
      committed_proposals: [],
      diagnostics: []
    }
  end

  defp apply_missed_quality(adaptation, input) do
    missed_quality =
      input
      |> Map.get(:recent_missed_work, [])
      |> Enum.filter(&quality_work?/1)

    if missed_quality == [] do
      adaptation
    else
      adaptation
      |> update_today(fn today ->
        Enum.map(today, fn work ->
          Map.put(
            work,
            :reason,
            "Missed quality work dropped, not stacked onto today."
          )
        end)
      end)
      |> add_proposal(%{
        kind: :shift_session,
        reason: :missed_quality,
        requires_approval: false,
        effect: :derived,
        text: "Missed Tuesday intervals dropped, not stacked onto today.",
        source_work: Enum.map(missed_quality, &work_key/1)
      })
    end
  end

  defp apply_illness(adaptation, input) do
    case recent_fever_illness(input) do
      nil ->
        adaptation

      illness ->
        days_since = Date.diff(Map.fetch!(input, :date), event_to(illness))

        adaptation
        |> replace_today(:rest, "#{days_since} day past a fever; full rest per the neck rule.")
        |> add_proposal(%{
          kind: :deload_week,
          amount: 0.5,
          requires_approval: false,
          effect: :derived,
          text: "Deload this week by 50% after illness."
        })
        |> add_proposal(%{
          kind: :shift_session,
          reason: :illness,
          requires_approval: false,
          effect: :derived,
          text: "Shift quality running until symptoms have cleared."
        })
    end
  end

  defp apply_injury(adaptation, input) do
    case active_injury(input) do
      nil ->
        adaptation

      injury ->
        area = event_value(injury, :area) || payload_value(injury, :area) || "injury"

        adaptation
        |> replace_today(
          :cross_train,
          "Running paused for #{area}; use cross-training or rest today."
        )
        |> add_proposal(%{
          kind: :deload_week,
          amount: 0.5,
          requires_approval: false,
          effect: :derived,
          text: "Deload running by 50% while the injury flag is active."
        })
    end
  end

  defp apply_holiday_reentry(adaptation, input) do
    date = Map.fetch!(input, :date)
    recent_load = input |> Map.fetch!(:recent_load_km) |> map_value(:value, 0)

    ended_window =
      input
      |> Map.get(:time_off_windows, [])
      |> Enum.find(fn window ->
        map_value(window, :availability) in [:fully_off, "fully_off"] and
          Date.diff(date, map_value(window, :ends_on)) == 1
      end)

    if ended_window && recent_load <= @low_reentry_load_km do
      adaptation
      |> replace_today(
        :easy_run,
        "First run back after time off; keep it easy and short."
      )
      |> add_proposal(%{
        kind: :rebuild_week,
        requires_approval: false,
        effect: :derived,
        text: "Rebuild this week after time off instead of resuming full load."
      })
    else
      adaptation
    end
  end

  defp keep_work(work) do
    %{
      owner_key: work_key(work),
      title: map_value(work, :title),
      action: :keep,
      reason: "Keep today's projected work."
    }
  end

  defp replace_today(adaptation, replacement, reason) do
    update_today(adaptation, fn today ->
      if today == [] do
        [
          %{
            owner_key: to_string(replacement),
            title: replacement_title(replacement),
            action: :add,
            replacement: replacement,
            reason: reason
          }
        ]
      else
        Enum.map(today, fn work ->
          work
          |> Map.put(:action, :replace)
          |> Map.put(:replacement, replacement)
          |> Map.put(:reason, reason)
        end)
      end
    end)
  end

  defp replacement_title(:rest), do: "Rest"
  defp replacement_title(:cross_train), do: "Cross-train"
  defp replacement_title(:easy_run), do: "Easy run"
  defp replacement_title(replacement), do: Phoenix.Naming.humanize(replacement)

  defp update_today(adaptation, fun) do
    Map.update!(adaptation, :today, fun)
  end

  defp add_proposal(adaptation, proposal) do
    Map.update!(adaptation, :proposals, &(&1 ++ [proposal]))
  end

  defp quality_work?(work) do
    work_key(work) in ["intervals", "tempo_run"] or
      String.contains?(String.downcase(to_string(map_value(work, :title, ""))), "interval")
  end

  defp recent_fever_illness(input) do
    date = Map.fetch!(input, :date)

    input
    |> life_events()
    |> Enum.find(fn event ->
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

  defp life_events(input) do
    Map.get(input, :life_events, [])
  end

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

  defp work_key(work) do
    map_value(work, :owner_key) ||
      map_value(work, :track_key) ||
      work
      |> map_value(:payload, %{})
      |> map_value(:track_key)
  end

  defp event_value(event, key, default \\ nil), do: map_value(event, key, default)

  defp map_value(map, key, default \\ nil)

  defp map_value(map, key, default) when is_map(map) do
    Map.get(map, key, Map.get(map, to_string(key), default))
  end

  defp map_value(_value, _key, default), do: default
end
