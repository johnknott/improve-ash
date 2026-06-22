defmodule Improve.Plans.AuthoredContentTest do
  use Improve.DataCase, async: true

  alias Improve.Accounts
  alias Improve.Plans

  describe "authored plan content" do
    test "users can define the reusable content inside a plan" do
      user = user!("author@example.com")
      plan = plan!(user, "Gym demo")

      item_type =
        Plans.create_item_type!(
          %{
            plan_id: plan.id,
            key: "exercise",
            name: "Exercise",
            description: "A strength movement",
            facts_schema: %{"required" => ["movement_pattern"]},
            display_hints: %{"icon" => "dumbbell"}
          },
          actor: user
        )

      item =
        Plans.create_item!(
          %{
            plan_id: plan.id,
            item_type_id: item_type.id,
            key: "chest_press",
            name: "Chest Press",
            facts: %{"movement_pattern" => "push"},
            stateful: false
          },
          actor: user
        )

      pool =
        Plans.create_pool!(
          %{
            plan_id: plan.id,
            key: "push",
            name: "Push exercises",
            description: "Pressing movements"
          },
          actor: user
        )

      membership =
        Plans.create_pool_membership!(
          %{
            plan_id: plan.id,
            pool_id: pool.id,
            item_id: item.id,
            metadata: %{"priority" => 1}
          },
          actor: user
        )

      environment =
        Plans.create_environment!(
          %{
            plan_id: plan.id,
            key: "jd_gym",
            name: "JD Gym",
            description: "Default gym",
            available_item_ids: [item.id]
          },
          actor: user
        )

      event_type =
        Plans.create_event_type!(
          %{
            plan_id: plan.id,
            key: "workout_set",
            name: "Workout set performed",
            description: "A completed exercise set",
            payload_schema: %{"required" => ["reps"]},
            item_link_roles: %{
              "roles" => [
                %{"role" => "exercise", "item_type_key" => "exercise", "required" => true}
              ]
            },
            effect_rules: %{"rules" => []}
          },
          actor: user
        )

      schedule =
        Plans.create_schedule!(
          %{
            plan_id: plan.id,
            owner_type: :session_template,
            owner_id: Ash.UUID.generate(),
            kind: :selected_weekdays,
            starts_on: ~D[2026-06-22],
            rules: %{"weekdays" => ["monday", "wednesday", "friday"]}
          },
          actor: user
        )

      assert item_type.plan_id == plan.id
      assert item.item_type_id == item_type.id
      assert membership.pool_id == pool.id
      assert environment.available_item_ids == [item.id]
      assert event_type.item_link_roles["roles"] != []
      assert schedule.kind == :selected_weekdays

      assert {:ok, [listed_item_type]} = Plans.list_item_types(actor: user)
      assert listed_item_type.id == item_type.id

      assert {:ok, [listed_item]} = Plans.list_items(actor: user)
      assert listed_item.id == item.id

      assert {:ok, [listed_pool]} = Plans.list_pools(actor: user)
      assert listed_pool.id == pool.id

      assert {:ok, [listed_membership]} = Plans.list_pool_memberships(actor: user)
      assert listed_membership.id == membership.id

      assert {:ok, [listed_environment]} = Plans.list_environments(actor: user)
      assert listed_environment.id == environment.id

      assert {:ok, [listed_event_type]} = Plans.list_event_types(actor: user)
      assert listed_event_type.id == event_type.id

      assert {:ok, [listed_schedule]} = Plans.list_schedules(actor: user)
      assert listed_schedule.id == schedule.id
    end

    test "authored content reads are scoped through plan ownership" do
      owner = user!("owner-content@example.com")
      other_user = user!("other-content@example.com")
      plan = plan!(owner, "Private authored content")

      item_type =
        Plans.create_item_type!(
          %{
            plan_id: plan.id,
            key: "book",
            name: "Book"
          },
          actor: owner
        )

      assert {:ok, []} = Plans.list_item_types(actor: other_user)
      assert {:error, %Ash.Error.Invalid{}} = Plans.get_item_type(item_type.id, actor: other_user)

      assert {:error, %Ash.Error.Forbidden{}} =
               Plans.create_item_type(
                 %{
                   plan_id: plan.id,
                   key: "supply",
                   name: "Supply"
                 },
                 actor: other_user
               )
    end
  end

  defp user!(email) do
    Accounts.create_user!(%{
      email: email,
      full_name: "Test User"
    })
  end

  defp plan!(user, name) do
    Plans.create_plan!(
      %{
        name: name,
        intention: "Prove authored content",
        starts_on: ~D[2026-06-22],
        ends_on: ~D[2026-07-20]
      },
      actor: user
    )
  end
end
