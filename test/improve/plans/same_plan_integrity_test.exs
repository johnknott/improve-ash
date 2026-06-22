defmodule Improve.Plans.SamePlanIntegrityTest do
  use Improve.DataCase, async: true

  alias Improve.Accounts
  alias Improve.Plans

  describe "same-plan integrity for authored plan definitions" do
    test "items cannot use an item type from another owned plan" do
      user = user!("same-plan-item@example.com")
      plan_a = plan!(user, "Plan A")
      plan_b = plan!(user, "Plan B")
      item_type_b = item_type!(user, plan_b, "exercise")

      assert_same_plan_error(fn ->
        Plans.create_item(
          %{
            plan_id: plan_a.id,
            item_type_id: item_type_b.id,
            key: "chest_press",
            name: "Chest Press"
          },
          actor: user
        )
      end)
    end

    test "pool memberships cannot mix pools and items across plans" do
      user = user!("same-plan-pool@example.com")
      plan_a = plan!(user, "Plan A")
      plan_b = plan!(user, "Plan B")
      item_type_a = item_type!(user, plan_a, "exercise")
      item_type_b = item_type!(user, plan_b, "exercise")
      pool_a = pool!(user, plan_a, "push")
      pool_b = pool!(user, plan_b, "push")
      item_a = item!(user, plan_a, item_type_a, "chest_press")
      item_b = item!(user, plan_b, item_type_b, "chest_press")

      assert_same_plan_error(fn ->
        Plans.create_pool_membership(
          %{
            plan_id: plan_a.id,
            pool_id: pool_b.id,
            item_id: item_a.id
          },
          actor: user
        )
      end)

      assert_same_plan_error(fn ->
        Plans.create_pool_membership(
          %{
            plan_id: plan_a.id,
            pool_id: pool_a.id,
            item_id: item_b.id
          },
          actor: user
        )
      end)
    end

    test "environments cannot list available items from another plan" do
      user = user!("same-plan-environment@example.com")
      plan_a = plan!(user, "Plan A")
      plan_b = plan!(user, "Plan B")
      item_type_b = item_type!(user, plan_b, "exercise")
      item_b = item!(user, plan_b, item_type_b, "bike")

      assert_same_plan_error(fn ->
        Plans.create_environment(
          %{
            plan_id: plan_a.id,
            key: "gym",
            name: "Gym",
            available_item_ids: [item_b.id]
          },
          actor: user
        )
      end)
    end

    test "session templates and slots cannot use foreign plan definitions" do
      user = user!("same-plan-session@example.com")
      plan_a = plan!(user, "Plan A")
      plan_b = plan!(user, "Plan B")
      item_type_a = item_type!(user, plan_a, "exercise")
      item_type_b = item_type!(user, plan_b, "exercise")
      item_a = item!(user, plan_a, item_type_a, "chest_press")
      item_b = item!(user, plan_b, item_type_b, "bike")
      pool_a = pool!(user, plan_a, "push")
      pool_b = pool!(user, plan_b, "cardio")
      pool_membership!(user, plan_a, pool_a, item_a)
      pool_membership!(user, plan_b, pool_b, item_b)
      environment_b = environment!(user, plan_b, "other_gym", [item_b.id])
      template_a = session_template!(user, plan_a, "upper")
      template_b = session_template!(user, plan_b, "lower")

      assert_same_plan_error(fn ->
        Plans.create_session_template(
          %{
            plan_id: plan_a.id,
            key: "lower",
            name: "Lower",
            environment_id: environment_b.id
          },
          actor: user
        )
      end)

      assert_same_plan_error(fn ->
        Plans.create_session_slot(
          %{
            plan_id: plan_a.id,
            session_template_id: template_a.id,
            key: "cardio",
            name: "Cardio",
            pool_id: pool_b.id
          },
          actor: user
        )
      end)

      assert_same_plan_error(fn ->
        Plans.create_session_slot(
          %{
            plan_id: plan_a.id,
            session_template_id: template_b.id,
            key: "push",
            name: "Push",
            pool_id: pool_a.id
          },
          actor: user
        )
      end)
    end

    test "direct goals and schedules cannot target foreign plan owners" do
      user = user!("same-plan-schedule@example.com")
      plan_a = plan!(user, "Plan A")
      plan_b = plan!(user, "Plan B")
      event_type_a = event_type!(user, plan_a, "read_pages")
      event_type_b = event_type!(user, plan_b, "dose")
      template_b = session_template!(user, plan_b, "other_session")
      direct_goal_a = direct_goal!(user, plan_a, event_type_a, "read")

      assert_same_plan_error(fn ->
        Plans.create_direct_goal(
          %{
            plan_id: plan_a.id,
            key: "dose",
            name: "Dose",
            event_type_id: event_type_b.id
          },
          actor: user
        )
      end)

      assert_same_plan_error(fn ->
        Plans.create_schedule(
          %{
            plan_id: plan_a.id,
            owner_type: :session_template,
            owner_id: template_b.id,
            kind: :selected_weekdays,
            starts_on: ~D[2026-06-22],
            rules: %{"weekdays" => ["monday"]}
          },
          actor: user
        )
      end)

      assert_same_plan_error(fn ->
        Plans.create_schedule(
          %{
            plan_id: plan_b.id,
            owner_type: :direct_goal,
            owner_id: direct_goal_a.id,
            kind: :every_day,
            starts_on: ~D[2026-06-22]
          },
          actor: user
        )
      end)
    end
  end

  defp assert_same_plan_error(fun) do
    assert {:error, %Ash.Error.Invalid{} = error} = fun.()
    assert Exception.message(error) =~ "same plan"
  end

  defp user!(email) do
    Accounts.create_user!(%{
      email: email,
      full_name: "Same Plan Tester"
    })
  end

  defp plan!(user, name) do
    Plans.create_plan!(
      %{
        name: name,
        intention: "Prove same-plan integrity",
        starts_on: ~D[2026-06-22],
        ends_on: ~D[2026-07-20]
      },
      actor: user
    )
  end

  defp item_type!(user, plan, key) do
    Plans.create_item_type!(
      %{
        plan_id: plan.id,
        key: key,
        name: String.replace(key, "_", " ")
      },
      actor: user
    )
  end

  defp item!(user, plan, item_type, key) do
    Plans.create_item!(
      %{
        plan_id: plan.id,
        item_type_id: item_type.id,
        key: key,
        name: String.replace(key, "_", " ")
      },
      actor: user
    )
  end

  defp pool!(user, plan, key) do
    Plans.create_pool!(
      %{
        plan_id: plan.id,
        key: key,
        name: String.replace(key, "_", " ")
      },
      actor: user
    )
  end

  defp pool_membership!(user, plan, pool, item) do
    Plans.create_pool_membership!(
      %{
        plan_id: plan.id,
        pool_id: pool.id,
        item_id: item.id
      },
      actor: user
    )
  end

  defp environment!(user, plan, key, item_ids) do
    Plans.create_environment!(
      %{
        plan_id: plan.id,
        key: key,
        name: String.replace(key, "_", " "),
        available_item_ids: item_ids
      },
      actor: user
    )
  end

  defp session_template!(user, plan, key) do
    Plans.create_session_template!(
      %{
        plan_id: plan.id,
        key: key,
        name: String.replace(key, "_", " ")
      },
      actor: user
    )
  end

  defp event_type!(user, plan, key) do
    Plans.create_event_type!(
      %{
        plan_id: plan.id,
        key: key,
        name: String.replace(key, "_", " ")
      },
      actor: user
    )
  end

  defp direct_goal!(user, plan, event_type, key) do
    Plans.create_direct_goal!(
      %{
        plan_id: plan.id,
        event_type_id: event_type.id,
        key: key,
        name: String.replace(key, "_", " ")
      },
      actor: user
    )
  end
end
