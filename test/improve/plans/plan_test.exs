defmodule Improve.Plans.PlanTest do
  use Improve.DataCase, async: true

  alias Improve.Accounts
  alias Improve.Plans

  describe "plans" do
    test "users can create and read their own plans" do
      user =
        Accounts.create_user!(%{
          email: "casey@example.com",
          full_name: "Casey Example"
        })

      plan =
        Plans.create_plan!(
          %{
            name: "Gym demo",
            intention: "Prove the gym planning model",
            starts_on: ~D[2026-06-22],
            ends_on: ~D[2026-07-20],
            source_kind: :demo,
            source_key: "gym"
          },
          actor: user
        )

      assert plan.user_id == user.id
      assert plan.status == :draft

      assert {:ok, [owned_plan]} = Plans.list_plans(actor: user)
      assert owned_plan.id == plan.id

      assert Plans.get_plan!(plan.id, actor: user).id == plan.id
    end

    test "plan reads are scoped to the actor" do
      owner =
        Accounts.create_user!(%{
          email: "owner@example.com",
          full_name: "Plan Owner"
        })

      other_user =
        Accounts.create_user!(%{
          email: "other@example.com",
          full_name: "Other User"
        })

      plan =
        Plans.create_plan!(
          %{
            name: "Private plan",
            intention: "Keep plan access owner scoped",
            starts_on: ~D[2026-06-22],
            ends_on: ~D[2026-07-20]
          },
          actor: owner
        )

      assert {:ok, []} = Plans.list_plans(actor: other_user)
      assert {:error, %Ash.Error.Invalid{}} = Plans.get_plan(plan.id, actor: other_user)
    end
  end
end
