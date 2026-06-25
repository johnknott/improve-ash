defmodule Improve.App.Proposal do
  @moduledoc """
  Applies approval-required proposal edits through core plan actions.

  Proposal records are not first-class persistence yet. This module is the small
  V1 bridge from a reviewed/approved proposal map to an existing durable action.
  """

  alias Improve.Plans
  alias Improve.Repo

  @notifications_key {__MODULE__, :notifications}

  def apply_proposal!(plan_or_id, proposal, opts) do
    case apply_proposal(plan_or_id, proposal, opts) do
      {:ok, result} ->
        result

      {:error, diagnostics} when is_list(diagnostics) ->
        raise ArgumentError, Enum.join(diagnostics, " ")

      {:error, error} ->
        raise error
    end
  end

  def apply_proposal(plan_or_id, proposal, opts) do
    actor = Keyword.fetch!(opts, :actor)

    with {:ok, plan} <- fetch_plan(plan_or_id, actor),
         {:ok, edit} <- proposed_edit(proposal),
         {:ok, applied_plan} <- apply_edit(plan, edit, actor) do
      {:ok, %{plan: applied_plan, action: edit.action, proposed_edit: edit}}
    end
  end

  defp fetch_plan(%{id: id}, actor), do: Plans.get_plan(id, actor: actor)
  defp fetch_plan(id, actor), do: Plans.get_plan(id, actor: actor)

  defp proposed_edit(%{proposed_edit: edit}) when is_map(edit), do: normalize_edit(edit)
  defp proposed_edit(%{"proposed_edit" => edit}) when is_map(edit), do: normalize_edit(edit)
  defp proposed_edit(edit) when is_map(edit), do: normalize_edit(edit)

  defp proposed_edit(_proposal) do
    {:error, ["Proposal is missing a proposed_edit map."]}
  end

  defp normalize_edit(edit) do
    action = value(edit, :action)

    case action do
      nil -> {:error, ["Proposal edit is missing an action."]}
      action -> {:ok, %{action: normalize_action(action), weeks: value(edit, :weeks)}}
    end
  end

  defp apply_edit(plan, %{action: :extend_plan, weeks: weeks}, actor) do
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
        {:ok, extended_plan}

      {:error, error} ->
        {:error, error}
    end
  end

  defp apply_edit(_plan, %{action: action}, _actor) do
    {:error, ["Proposal action #{action} is not supported yet."]}
  end

  defp normalize_action(action) when is_atom(action), do: action
  defp normalize_action("extend_plan"), do: :extend_plan
  defp normalize_action("adjust_goal"), do: :adjust_goal
  defp normalize_action(action) when is_binary(action), do: action

  defp value(map, key) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
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
