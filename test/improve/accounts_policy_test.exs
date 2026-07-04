defmodule Improve.AccountsPolicyTest do
  use Improve.DataCase, async: true

  alias Improve.Accounts

  describe "user read isolation" do
    test "a user cannot read another user's record" do
      owner = Accounts.create_user!(%{email: "policy-owner@example.test", full_name: "Owner"})
      other = Accounts.create_user!(%{email: "policy-other@example.test", full_name: "Other"})

      assert {:error, %Ash.Error.Invalid{}} = Accounts.get_user(other.id, actor: owner)

      assert {:error, %Ash.Error.Invalid{}} =
               Accounts.get_user_by_email(other.email, actor: owner)
    end

    test "list_users returns only the actor" do
      owner =
        Accounts.create_user!(%{email: "policy-list-owner@example.test", full_name: "Owner"})

      Accounts.create_user!(%{email: "policy-list-other@example.test", full_name: "Other"})

      assert {:ok, [visible]} = Accounts.list_users(actor: owner)
      assert visible.id == owner.id
    end

    test "reads without an actor are forbidden" do
      user = Accounts.create_user!(%{email: "policy-anon@example.test", full_name: "Anon"})

      assert {:error, %Ash.Error.Forbidden{}} = Accounts.get_user(user.id)
      assert {:error, %Ash.Error.Forbidden{}} = Accounts.list_users()
    end

    test "a user can read their own record" do
      user = Accounts.create_user!(%{email: "policy-self@example.test", full_name: "Self"})

      assert {:ok, found} = Accounts.get_user(user.id, actor: user)
      assert found.id == user.id
    end
  end

  describe "user write isolation" do
    test "a user can update their own profile but not another user's" do
      owner = Accounts.create_user!(%{email: "policy-up-owner@example.test", full_name: "Owner"})
      other = Accounts.create_user!(%{email: "policy-up-other@example.test", full_name: "Other"})

      assert {:ok, updated} =
               Accounts.complete_profile(owner, %{full_name: "Renamed"}, actor: owner)

      assert updated.full_name == "Renamed"

      assert {:error, %Ash.Error.Forbidden{}} =
               Accounts.complete_profile(other, %{full_name: "Hijacked"}, actor: owner)
    end
  end

  describe "token isolation" do
    test "tokens are not readable outside authentication flows" do
      user = Accounts.create_user!(%{email: "policy-token@example.test", full_name: "Token"})

      assert {:error, %Ash.Error.Forbidden{}} = Ash.read(Improve.Accounts.Token, actor: user)
    end
  end
end
