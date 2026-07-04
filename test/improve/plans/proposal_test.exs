defmodule Improve.Plans.ProposalTest do
  use Improve.DataCase, async: true

  alias Improve.Accounts
  alias Improve.Plans

  describe "proposal lifecycle" do
    test "create, approve, and mark applied" do
      user = user!()
      plan = plan!(user)

      {:ok, proposal} =
        Plans.create_proposal(
          %{
            plan_id: plan.id,
            kind: "extend_plan",
            source_evaluator: "marathon",
            proposed_edit: %{"action" => "extend_plan", "weeks" => 1},
            text: "Consider extending the plan by 1 week after illness."
          },
          actor: user
        )

      assert proposal.status == :proposed
      assert proposal.kind == "extend_plan"

      {:ok, approved} = Plans.approve_proposal(proposal, actor: user)
      assert approved.status == :approved
      assert approved.decided_at != nil

      {:ok, applied} = Plans.mark_proposal_applied(approved, actor: user)
      assert applied.status == :applied
      assert applied.applied_at != nil
    end

    test "dismiss with reason" do
      user = user!()
      plan = plan!(user)

      {:ok, proposal} =
        Plans.create_proposal(
          %{
            plan_id: plan.id,
            kind: "adjust_goal",
            source_evaluator: "marathon",
            proposed_edit: %{"action" => "adjust_goal"},
            text: "Consider adjusting the goal."
          },
          actor: user
        )

      {:ok, dismissed} =
        Plans.dismiss_proposal(proposal, %{dismiss_reason: "Not needed"}, actor: user)

      assert dismissed.status == :dismissed
      assert dismissed.dismiss_reason == "Not needed"
      assert dismissed.decided_at != nil
    end

    test "cannot approve a dismissed proposal" do
      user = user!()
      plan = plan!(user)

      {:ok, proposal} =
        Plans.create_proposal(
          %{
            plan_id: plan.id,
            kind: "extend_plan",
            source_evaluator: "marathon",
            proposed_edit: %{"action" => "extend_plan", "weeks" => 1},
            text: "Extend plan."
          },
          actor: user
        )

      {:ok, dismissed} =
        Plans.dismiss_proposal(proposal, %{dismiss_reason: "No"}, actor: user)

      assert {:error, _} = Plans.approve_proposal(dismissed, actor: user)
    end

    test "divergence_key uniqueness: only one proposed per plan+key" do
      user = user!()
      plan = plan!(user)

      {:ok, _p1} =
        Plans.create_proposal(
          %{
            plan_id: plan.id,
            kind: "extend_plan",
            source_evaluator: "marathon",
            proposed_edit: %{"action" => "extend_plan", "weeks" => 1},
            text: "First proposal.",
            divergence_key: "extend_plan"
          },
          actor: user
        )

      assert {:error, _} =
               Plans.create_proposal(
                 %{
                   plan_id: plan.id,
                   kind: "extend_plan",
                   source_evaluator: "marathon",
                   proposed_edit: %{"action" => "extend_plan", "weeks" => 2},
                   text: "Duplicate.",
                   divergence_key: "extend_plan"
                 },
                 actor: user
               )
    end
  end

  defp user! do
    Accounts.create_user!(%{
      email: "proposal-test-#{System.unique_integer([:positive])}@example.test",
      full_name: "Test User"
    })
  end

  defp plan!(user) do
    Plans.create_plan!(
      %{
        name: "Test Plan",
        intention: "test",
        starts_on: ~D[2026-06-01],
        ends_on: ~D[2026-08-01]
      },
      actor: user
    )
  end
end
