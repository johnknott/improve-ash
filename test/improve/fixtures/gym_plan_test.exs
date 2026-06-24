defmodule Improve.Fixtures.GymPlanTest do
  use Improve.DataCase, async: true

  alias Improve.Accounts
  alias Improve.Fixtures.GymPlan
  alias Improve.Plans

  describe "install!/2" do
    test "installs the persisted gym demo plan with valid references" do
      user =
        Accounts.create_user!(%{
          email: "gym-demo@example.com",
          full_name: "Gym Demo"
        })

      result = GymPlan.install!(user, starts_on: ~D[2026-06-22])
      plan = result.plan

      assert plan.name == "General Fitness"
      assert plan.intention == "Build consistent gym progress"
      assert plan.starts_on == ~D[2026-06-22]
      assert plan.ends_on == ~D[2026-08-17]
      assert plan.status == :active
      assert plan.source_kind == :demo
      assert plan.source_key == "gym"

      assert Plans.summarize_plan!(plan, actor: user) == %{
               item_types: 3,
               items: 8,
               pools: 3,
               pool_memberships: 7,
               environments: 1,
               event_types: 2,
               session_templates: 1,
               session_slots: 3,
               tracks: 0,
               schedules: 1
             }

      item_types = list!(Plans.list_item_types(actor: user, query: [filter: [plan_id: plan.id]]))
      items = list!(Plans.list_items(actor: user, query: [filter: [plan_id: plan.id]]))
      pools = list!(Plans.list_pools(actor: user, query: [filter: [plan_id: plan.id]]))

      memberships =
        list!(Plans.list_pool_memberships(actor: user, query: [filter: [plan_id: plan.id]]))

      environments =
        list!(Plans.list_environments(actor: user, query: [filter: [plan_id: plan.id]]))

      event_types =
        list!(Plans.list_event_types(actor: user, query: [filter: [plan_id: plan.id]]))

      templates =
        list!(Plans.list_session_templates(actor: user, query: [filter: [plan_id: plan.id]]))

      slots = list!(Plans.list_session_slots(actor: user, query: [filter: [plan_id: plan.id]]))
      schedules = list!(Plans.list_schedules(actor: user, query: [filter: [plan_id: plan.id]]))

      assert keys(item_types) == ["cardio_machine", "exercise", "gym_environment"]

      assert names(items) == [
               "Bike",
               "Cable Fly",
               "Chest Press",
               "JD Gym",
               "Lat Pulldown",
               "Rower",
               "Seated Row",
               "Shoulder Press"
             ]

      assert keys(pools) == ["cardio", "pull", "push"]
      assert keys(event_types) == ["cardio_block_performed", "workout_exercise_performed"]

      assert [%{key: "jd_gym", name: "JD Gym"} = environment] = environments

      assert [%{key: "upper_biased_gym_visit", name: "Upper-biased gym visit"} = template] =
               templates

      assert [%{kind: :times_per_week, owner_type: :session_template} = schedule] = schedules
      assert schedule.owner_id == template.id

      slot_counts =
        slots
        |> Map.new(fn slot -> {slot.key, {slot.count, slot.position}} end)

      assert slot_counts == %{
               "cardio" => {1, 3},
               "pull" => {2, 2},
               "push" => {2, 1}
             }

      item_ids = MapSet.new(Enum.map(items, & &1.id))
      pool_ids = MapSet.new(Enum.map(pools, & &1.id))

      assert Enum.all?(memberships, fn membership ->
               MapSet.member?(item_ids, membership.item_id) and
                 MapSet.member?(pool_ids, membership.pool_id)
             end)

      assert Enum.all?(slots, fn slot -> MapSet.member?(pool_ids, slot.pool_id) end)
      assert Enum.all?(environment.available_item_ids, &MapSet.member?(item_ids, &1))
    end
  end

  defp list!({:ok, records}), do: records

  defp keys(records) do
    records
    |> Enum.map(& &1.key)
    |> Enum.sort()
  end

  defp names(records) do
    records
    |> Enum.map(& &1.name)
    |> Enum.sort()
  end
end
