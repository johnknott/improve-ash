defmodule Improve.App.Proposal do
  @moduledoc """
  Applies approval-required proposal edits through the action registry.
  """

  alias Improve.App.ProposalActions
  alias Improve.Plans

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
         {:ok, edit} <- proposed_edit(proposal) do
      ProposalActions.apply_edit(plan, edit, actor)
    end
  end

  defp fetch_plan(%{id: id}, actor), do: Plans.get_plan(id, actor: actor)
  defp fetch_plan(id, actor), do: Plans.get_plan(id, actor: actor)

  defp proposed_edit(%{proposed_edit: edit}) when is_map(edit), do: {:ok, edit}
  defp proposed_edit(%{"proposed_edit" => edit}) when is_map(edit), do: {:ok, edit}
  defp proposed_edit(edit) when is_map(edit) and is_map_key(edit, :action), do: {:ok, edit}
  defp proposed_edit(edit) when is_map(edit) and is_map_key(edit, "action"), do: {:ok, edit}

  defp proposed_edit(_proposal) do
    {:error, ["Proposal is missing a proposed_edit map."]}
  end
end
