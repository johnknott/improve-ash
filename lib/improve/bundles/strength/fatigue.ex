defmodule Improve.Bundles.Strength.Fatigue do
  @moduledoc """
  Derives a fatigue signal from recent strength training session density.

  Counts sessions in the last N days and produces a normalized fatigue score
  (0.0 = fully rested, 1.0 = very fatigued). This is intentionally simple —
  a real implementation would weight by volume/intensity, but this proves
  the evaluator pattern works.
  """

  alias Improve.Planning.LocalDate

  @lookback_days 7
  @high_density_threshold 5

  def evaluate(%{date: date, tracks: tracks, journal_events: journal_events, timezone: timezone}) do
    strength_track_ids = strength_track_ids(tracks)

    recent_sessions =
      journal_events
      |> Enum.filter(fn event ->
        track_id = Map.get(event, :track_id) || Map.get(event, "track_id")
        status = Map.get(event, :status) || Map.get(event, "status")
        effective_at = Map.get(event, :effective_at) || Map.get(event, "effective_at")

        track_id in strength_track_ids and
          status == :active and
          within_lookback?(effective_at, date, timezone)
      end)

    session_count = count_unique_days(recent_sessions, timezone)
    score = min(session_count / @high_density_threshold, 1.0)

    {:ok,
     %{
       strength_fatigue: %{
         score: score,
         session_count: session_count,
         lookback_days: @lookback_days,
         high: score >= 0.8
       }
     }, []}
  end

  defp strength_track_ids(tracks) do
    tracks
    |> Enum.filter(&strength_track?/1)
    |> Enum.map(& &1.id)
    |> MapSet.new()
  end

  defp strength_track?(track) do
    target = Map.get(track, :target) || %{}
    type = Map.get(target, "type") || Map.get(target, :type) || ""
    key = Map.get(track, :key) || ""

    type == "responsive_progression" or
      String.contains?(key, "strength") or
      String.contains?(key, "lift")
  end

  defp within_lookback?(nil, _date, _timezone), do: false

  defp within_lookback?(effective_at, date, timezone) do
    event_date = LocalDate.to_date(effective_at, timezone)
    cutoff = Date.add(date, -@lookback_days)
    Date.compare(event_date, cutoff) != :lt and Date.compare(event_date, date) == :lt
  end

  defp count_unique_days(events, timezone) do
    events
    |> Enum.map(fn event ->
      effective_at = Map.get(event, :effective_at) || Map.get(event, "effective_at")
      LocalDate.to_date(effective_at, timezone)
    end)
    |> Enum.uniq()
    |> length()
  end
end
