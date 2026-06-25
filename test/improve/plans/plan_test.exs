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

    test "users can extend their own plan by whole weeks" do
      user =
        Accounts.create_user!(%{
          email: "extend-plan@example.com",
          full_name: "Extend Plan"
        })

      plan =
        Plans.create_plan!(
          %{
            name: "Race plan",
            intention: "Move the deadline deliberately",
            starts_on: ~D[2026-06-22],
            ends_on: ~D[2026-10-04]
          },
          actor: user
        )

      assert {:ok, extended} = Plans.extend_plan(plan, %{weeks: 2}, actor: user)
      assert extended.ends_on == ~D[2026-10-18]
    end

    test "plan extension requires positive weeks" do
      user =
        Accounts.create_user!(%{
          email: "extend-plan-invalid@example.com",
          full_name: "Extend Plan Invalid"
        })

      plan =
        Plans.create_plan!(
          %{
            name: "Race plan",
            intention: "Move the deadline deliberately",
            starts_on: ~D[2026-06-22],
            ends_on: ~D[2026-10-04]
          },
          actor: user
        )

      assert {:error, %Ash.Error.Invalid{}} = Plans.extend_plan(plan, %{weeks: 0}, actor: user)
    end

    test "users cannot extend another user's plan" do
      owner =
        Accounts.create_user!(%{
          email: "extend-plan-owner@example.com",
          full_name: "Extend Plan Owner"
        })

      other_user =
        Accounts.create_user!(%{
          email: "extend-plan-other@example.com",
          full_name: "Extend Plan Other"
        })

      plan =
        Plans.create_plan!(
          %{
            name: "Private plan",
            intention: "Keep plan updates owner scoped",
            starts_on: ~D[2026-06-22],
            ends_on: ~D[2026-10-04]
          },
          actor: owner
        )

      assert {:error, %Ash.Error.Forbidden{}} =
               Plans.extend_plan(plan, %{weeks: 1}, actor: other_user)
    end
  end
end
