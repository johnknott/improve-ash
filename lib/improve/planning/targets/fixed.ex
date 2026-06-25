defmodule Improve.Planning.Targets.Fixed do
  @moduledoc false

  @behaviour Improve.Planning.Targets.Evaluator

  def target_type, do: "fixed"

  def diagnostics(_evaluation), do: []

  def completion(%{track: track, date: date, journal_events: journal_events}) do
    completed_events =
      journal_events
      |> Enum.filter(&completed_event_for?(track, date, &1))

    status =
      case completed_events do
        [_event | _events] -> :completed
        [] -> :incomplete
      end

    {:ok,
     %{
       status: status,
       completed_events: completed_events,
       progress: progress(completed_events)
     }, []}
  end

  defp completed_event_for?(_track, nil, _event), do: false

  defp completed_event_for?(track, date, event) do
    event_value(event, :track_id) == track.id and event_value(event, :status) == :active and
      Date.compare(DateTime.to_date(event_value(event, :effective_at)), date) == :eq
  end

  defp progress([]) do
    %{
      completed_event_count: 0,
      completed_event_ids: [],
      label: "0 linked journal events"
    }
  end

  defp progress(events) do
    %{
      completed_event_count: length(events),
      completed_event_ids: Enum.map(events, &event_value(&1, :id)),
      label: "#{length(events)} linked journal event(s)"
    }
  end

  defp event_value(event, key), do: Map.get(event, key) || Map.get(event, to_string(key))
end
