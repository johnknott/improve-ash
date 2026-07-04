defmodule Improve.App.ProposalSync do
  @moduledoc """
  Upserts durable proposals from evaluator output during projection.

  When a projection produces committed proposals, this module persists them:
  - New proposals (by divergence_key) are created as :proposed
  - Existing proposals with the same divergence_key are refreshed
  - Previously dismissed proposals with the same key are not re-proposed
  """

  alias Improve.Plans

  def sync_proposals(plan_id, evaluator_output, actor) do
    committed_proposals = extract_committed_proposals(evaluator_output)

    if committed_proposals == [] do
      {:ok, []}
    else
      sync_each(plan_id, committed_proposals, actor)
    end
  end

  defp extract_committed_proposals(nil), do: []

  defp extract_committed_proposals(evaluator_output) when is_map(evaluator_output) do
    evaluator_output
    |> Map.get(:marathon_adaptation, %{})
    |> Map.get(:committed_proposals, [])
  end

  defp extract_committed_proposals(_), do: []

  defp sync_each(plan_id, proposals, actor) do
    results =
      Enum.map(proposals, fn proposal ->
        divergence_key = divergence_key(proposal)

        case find_existing(plan_id, divergence_key, actor) do
          {:ok, existing} ->
            refresh_existing(existing, proposal, actor)

          :not_found ->
            if recently_dismissed?(plan_id, divergence_key, actor) do
              {:ok, :skipped}
            else
              create_proposal(plan_id, proposal, divergence_key, actor)
            end
        end
      end)

    proposals =
      results
      |> Enum.filter(fn
        {:ok, %{id: _}} -> true
        _ -> false
      end)
      |> Enum.map(fn {:ok, p} -> p end)

    {:ok, proposals}
  end

  defp find_existing(_plan_id, nil, _actor), do: :not_found

  defp find_existing(plan_id, divergence_key, actor) do
    case Plans.list_proposals(
           actor: actor,
           query: [
             filter: [plan_id: plan_id, divergence_key: divergence_key, status: :proposed],
             limit: 1
           ]
         ) do
      {:ok, [existing | _]} -> {:ok, existing}
      _ -> :not_found
    end
  end

  defp recently_dismissed?(_plan_id, nil, _actor), do: false

  defp recently_dismissed?(plan_id, divergence_key, actor) do
    case Plans.list_proposals(
           actor: actor,
           query: [
             filter: [plan_id: plan_id, divergence_key: divergence_key, status: :dismissed],
             limit: 1
           ]
         ) do
      {:ok, [_ | _]} -> true
      _ -> false
    end
  end

  defp refresh_existing(existing, proposal, actor) do
    Plans.refresh_proposal(existing, proposal_refresh_attrs(proposal), actor: actor)
  end

  defp create_proposal(plan_id, proposal, divergence_key, actor) do
    Plans.create_proposal(proposal_create_attrs(plan_id, proposal, divergence_key), actor: actor)
  end

  defp proposal_create_attrs(plan_id, proposal, divergence_key) do
    %{
      plan_id: plan_id,
      status: :proposed,
      kind: to_string(Map.get(proposal, :kind, "unknown")),
      source_evaluator: to_string(Map.get(proposal, :source, "marathon")),
      proposed_edit: Map.get(proposal, :proposed_edit, %{}),
      evidence: Map.get(proposal, :evidence, %{}),
      affected_fields: Map.get(proposal, :affected_fields, []),
      text: Map.get(proposal, :text, ""),
      divergence_key: divergence_key
    }
  end

  defp proposal_refresh_attrs(proposal) do
    %{
      proposed_edit: Map.get(proposal, :proposed_edit, %{}),
      evidence: Map.get(proposal, :evidence, %{}),
      text: Map.get(proposal, :text, ""),
      affected_fields: Map.get(proposal, :affected_fields, [])
    }
  end

  defp divergence_key(proposal) do
    kind = Map.get(proposal, :kind)

    if kind do
      "#{kind}"
    end
  end
end
