defmodule Improve.App.ProposalActions do
  @moduledoc """
  Registry of proposal actions that can be applied to a plan.

  Each registered action implements `apply/3`: (plan, edit, actor) -> {:ok, plan} | {:error, term}.
  Unknown actions degrade gracefully with a diagnostic instead of crashing.
  """

  alias Improve.Plans
  alias Improve.Repo

  @notifications_key {__MODULE__, :notifications}

  @doc """
  Applies a proposed edit to a plan via the action registry.
  """
  def apply_edit(plan, %{action: action} = edit, actor) do
    case lookup(action) do
      {:ok, apply_fn} ->
        apply_fn.(plan, edit, actor)

      {:error, :unknown} ->
        {:error, ["Proposal action #{action} is not recognized."]}

      {:error, :unsupported} ->
        {:error, ["Proposal action #{action} is recognized but not yet supported."]}
    end
  end

  def apply_edit(plan, edit, actor) when is_map(edit) do
    action = Map.get(edit, "action")

    if action do
      apply_edit(plan, Map.put(edit, :action, normalize_action(action)), actor)
    else
      {:error, ["Proposal edit is missing an action."]}
    end
  end

  @registry %{
    extend_plan: &__MODULE__.apply_extend_plan/3,
    adjust_goal: &__MODULE__.apply_adjust_goal/3,
    rebase_progression: &__MODULE__.apply_rebase_progression/3
  }

  @recognized_unsupported [:compress_taper]

  defp lookup(action) when is_atom(action) do
    cond do
      Map.has_key?(@registry, action) -> {:ok, Map.fetch!(@registry, action)}
      action in @recognized_unsupported -> {:error, :unsupported}
      true -> {:error, :unknown}
    end
  end

  defp lookup(action) when is_binary(action) do
    lookup(normalize_action(action))
  end

  defp normalize_action(action) when is_atom(action), do: action
  defp normalize_action("extend_plan"), do: :extend_plan
  defp normalize_action("adjust_goal"), do: :adjust_goal
  defp normalize_action("rebase_progression"), do: :rebase_progression
  defp normalize_action("compress_taper"), do: :compress_taper
  defp normalize_action(action) when is_binary(action), do: String.to_atom(action)

  # --- extend_plan ---

  def apply_extend_plan(plan, edit, actor) do
    weeks = Map.get(edit, :weeks) || Map.get(edit, "weeks") || 1

    case Repo.transaction(fn ->
           reset_notifications!()

           try do
             with {:ok, extended_plan} <- extend_plan(plan, weeks, actor),
                  {:ok, _schedules} <- extend_matching_schedules(plan, extended_plan, actor) do
               {extended_plan, take_notifications!()}
             else
               {:error, error} -> Repo.rollback(error)
             end
           after
             Process.delete(@notifications_key)
           end
         end) do
      {:ok, {extended_plan, notifications}} ->
        Ash.Notifier.notify(notifications)
        {:ok, %{plan: extended_plan, action: :extend_plan, proposed_edit: edit}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp extend_plan(plan, weeks, actor) do
    case Plans.extend_plan(plan, %{weeks: weeks}, actor: actor, return_notifications?: true) do
      {:ok, plan, notifications} ->
        collect_notifications!(notifications)
        {:ok, plan}

      {:error, error} ->
        {:error, error}
    end
  end

  defp extend_matching_schedules(plan, extended_plan, actor) do
    with {:ok, schedules} <-
           Plans.list_schedules(actor: actor, query: [filter: [plan_id: plan.id]]) do
      schedules
      |> Enum.filter(&(&1.ends_on == plan.ends_on))
      |> Enum.reduce_while({:ok, []}, fn schedule, {:ok, updated} ->
        case update_schedule(schedule, extended_plan.ends_on, actor) do
          {:ok, schedule} -> {:cont, {:ok, [schedule | updated]}}
          {:error, error} -> {:halt, {:error, error}}
        end
      end)
    end
  end

  defp update_schedule(schedule, ends_on, actor) do
    case Plans.update_schedule(
           schedule,
           %{ends_on: ends_on},
           actor: actor,
           return_notifications?: true
         ) do
      {:ok, schedule, notifications} ->
        collect_notifications!(notifications)
        {:ok, schedule}

      {:error, error} ->
        {:error, error}
    end
  end

  # --- adjust_goal ---

  def apply_adjust_goal(plan, edit, actor) do
    track_id = Map.get(edit, :track_id) || Map.get(edit, "track_id")
    target_changes = Map.get(edit, :target_changes) || Map.get(edit, "target_changes") || %{}

    with {:ok, track} <- get_track(plan, track_id, actor),
         {:ok, updated_track} <- merge_target(track, target_changes, actor) do
      {:ok, %{plan: plan, track: updated_track, action: :adjust_goal}}
    end
  end

  defp get_track(_plan, nil, _actor), do: {:error, ["adjust_goal requires a track_id."]}

  defp get_track(plan, track_id, actor) do
    case Plans.get_track(track_id, actor: actor) do
      {:ok, %{plan_id: plan_id} = track} when plan_id == plan.id -> {:ok, track}
      _ -> {:error, ["Track not found or belongs to another plan."]}
    end
  end

  defp merge_target(track, target_changes, actor) when is_map(target_changes) do
    new_target = Map.merge(track.target, target_changes)
    Plans.update_track(track, %{target: new_target}, actor: actor)
  end

  # --- rebase_progression ---

  def apply_rebase_progression(plan, edit, actor) do
    track_id = Map.get(edit, :track_id) || Map.get(edit, "track_id")
    shift_weeks = Map.get(edit, :shift_weeks) || Map.get(edit, "shift_weeks") || 0

    with {:ok, track} <- get_track(plan, track_id, actor),
         {:ok, updated_track} <- shift_progression(track, shift_weeks, actor) do
      {:ok, %{plan: plan, track: updated_track, action: :rebase_progression}}
    end
  end

  defp shift_progression(track, shift_weeks, actor) do
    target = track.target
    progression = Map.get(target, "progression") || %{}

    starts_on = parse_date(Map.get(target, "starts_on") || Map.get(progression, "starts_on"))
    ends_on = parse_date(Map.get(target, "ends_on") || Map.get(progression, "ends_on"))

    shift_days = shift_weeks * 7

    new_target =
      target
      |> maybe_shift_date("starts_on", starts_on, shift_days)
      |> maybe_shift_date("ends_on", ends_on, shift_days)
      |> maybe_shift_progression(progression, shift_days)

    Plans.update_track(track, %{target: new_target}, actor: actor)
  end

  defp maybe_shift_date(target, _key, nil, _shift), do: target

  defp maybe_shift_date(target, key, date, shift) do
    Map.put(target, key, Date.to_iso8601(Date.add(date, shift)))
  end

  defp maybe_shift_progression(target, progression, shift_days) when map_size(progression) > 0 do
    shifted =
      progression
      |> maybe_shift_date("starts_on", parse_date(Map.get(progression, "starts_on")), shift_days)
      |> maybe_shift_date("ends_on", parse_date(Map.get(progression, "ends_on")), shift_days)

    Map.put(target, "progression", shifted)
  end

  defp maybe_shift_progression(target, _progression, _shift_days), do: target

  defp parse_date(nil), do: nil
  defp parse_date(%Date{} = d), do: d

  defp parse_date(s) when is_binary(s) do
    case Date.from_iso8601(s) do
      {:ok, d} -> d
      _ -> nil
    end
  end

  defp parse_date(_), do: nil

  # --- notifications ---

  defp reset_notifications! do
    Process.put(@notifications_key, [])
  end

  defp collect_notifications!(notifications) do
    Process.put(@notifications_key, Process.get(@notifications_key, []) ++ notifications)
  end

  defp take_notifications! do
    notifications = Process.get(@notifications_key, [])
    Process.delete(@notifications_key)
    notifications
  end
end
