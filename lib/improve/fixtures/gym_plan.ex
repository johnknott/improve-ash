defmodule Improve.Fixtures.GymPlan do
  @moduledoc """
  Installs the gym demo plan used by the headless POC scenario tests.
  """

  alias Improve.Plans
  alias Improve.Repo

  @eight_weeks 8 * 7
  @notifications_key {__MODULE__, :notifications}

  def install!(user, opts) do
    starts_on = Keyword.fetch!(opts, :starts_on)

    Repo.transaction(fn ->
      reset_notifications!()

      plan =
        create!(:create_plan!, user, %{
          name: "General Fitness",
          intention: "Build consistent gym progress",
          starts_on: starts_on,
          ends_on: Date.add(starts_on, @eight_weeks),
          status: :active,
          source_kind: :demo,
          source_key: "gym"
        })

      item_types = install_item_types!(plan, user)
      items = install_items!(plan, item_types, user)
      pools = install_pools!(plan, items, user)
      environment = install_environment!(plan, items, user)
      event_types = install_event_types!(plan, item_types, user)
      session_template = install_session_template!(plan, environment, user)
      slots = install_session_slots!(plan, session_template, pools, user)
      schedule = install_schedule!(plan, session_template, starts_on, user)

      result = %{
        plan: plan,
        item_types: item_types,
        items: items,
        pools: pools,
        environment: environment,
        event_types: event_types,
        session_template: session_template,
        session_slots: slots,
        schedule: schedule
      }

      {result, take_notifications!()}
    end)
    |> case do
      {:ok, {result, notifications}} ->
        Ash.Notifier.notify(notifications)
        result

      {:error, error} ->
        raise inspect(error)
    end
  end

  defp install_item_types!(plan, user) do
    %{
      exercise:
        item_type!(plan, user, %{
          key: "exercise",
          name: "Exercise",
          description: "A strength movement",
          facts_schema: %{"optional" => ["movement_pattern", "equipment"]},
          display_hints: %{"kind" => "strength"}
        }),
      cardio_machine:
        item_type!(plan, user, %{
          key: "cardio_machine",
          name: "Cardio Machine",
          description: "A cardio option",
          facts_schema: %{"optional" => ["modality"]},
          display_hints: %{"kind" => "cardio"}
        }),
      gym_environment:
        item_type!(plan, user, %{
          key: "gym_environment",
          name: "Gym Environment",
          description: "A place where gym work happens",
          facts_schema: %{"optional" => ["location"]},
          display_hints: %{"kind" => "environment"}
        })
    }
  end

  defp install_items!(plan, item_types, user) do
    %{
      chest_press:
        item!(plan, user, item_types.exercise, "chest_press", "Chest Press", %{
          "movement_pattern" => "push",
          "equipment" => "machine"
        }),
      shoulder_press:
        item!(plan, user, item_types.exercise, "shoulder_press", "Shoulder Press", %{
          "movement_pattern" => "push",
          "equipment" => "machine"
        }),
      cable_fly:
        item!(plan, user, item_types.exercise, "cable_fly", "Cable Fly", %{
          "movement_pattern" => "push",
          "equipment" => "cable"
        }),
      lat_pulldown:
        item!(plan, user, item_types.exercise, "lat_pulldown", "Lat Pulldown", %{
          "movement_pattern" => "pull",
          "equipment" => "cable"
        }),
      seated_row:
        item!(plan, user, item_types.exercise, "seated_row", "Seated Row", %{
          "movement_pattern" => "pull",
          "equipment" => "cable"
        }),
      bike: item!(plan, user, item_types.cardio_machine, "bike", "Bike", %{"modality" => "bike"}),
      rower:
        item!(plan, user, item_types.cardio_machine, "rower", "Rower", %{"modality" => "rower"}),
      jd_gym:
        item!(plan, user, item_types.gym_environment, "jd_gym", "JD Gym", %{
          "location" => "default"
        })
    }
  end

  defp install_pools!(plan, items, user) do
    push = pool!(plan, user, "push", "Push", "Pressing movements")
    pull = pool!(plan, user, "pull", "Pull", "Pulling movements")
    cardio = pool!(plan, user, "cardio", "Cardio", "Cardio machines")

    for item <- [items.chest_press, items.shoulder_press, items.cable_fly] do
      pool_membership!(plan, user, push, item)
    end

    for item <- [items.lat_pulldown, items.seated_row] do
      pool_membership!(plan, user, pull, item)
    end

    for item <- [items.bike, items.rower] do
      pool_membership!(plan, user, cardio, item)
    end

    %{push: push, pull: pull, cardio: cardio}
  end

  defp install_environment!(plan, items, user) do
    available_item_ids =
      [
        items.chest_press,
        items.shoulder_press,
        items.cable_fly,
        items.lat_pulldown,
        items.seated_row,
        items.bike,
        items.rower
      ]
      |> Enum.map(& &1.id)

    create!(:create_environment!, user, %{
      plan_id: plan.id,
      key: "jd_gym",
      name: "JD Gym",
      description: "Default gym",
      available_item_ids: available_item_ids
    })
  end

  defp install_event_types!(plan, item_types, user) do
    %{
      workout_exercise:
        create!(
          :create_event_type!,
          user,
          %{
            plan_id: plan.id,
            key: "workout_exercise_performed",
            name: "Workout exercise performed",
            description: "A strength exercise was performed",
            payload_schema: %{
              "required" => ["sets", "reps"],
              "optional" => ["load", "load_unit", "rpe"]
            },
            item_link_roles: %{
              "roles" => [
                %{
                  "role" => "exercise",
                  "item_type_key" => item_types.exercise.key,
                  "required" => true
                },
                %{
                  "role" => "environment",
                  "item_type_key" => item_types.gym_environment.key,
                  "required" => false
                }
              ]
            },
            effect_rules: %{"rules" => []}
          }
        ),
      cardio_block:
        create!(
          :create_event_type!,
          user,
          %{
            plan_id: plan.id,
            key: "cardio_block_performed",
            name: "Cardio block performed",
            description: "A cardio block was performed",
            payload_schema: %{
              "required" => ["duration_minutes"],
              "optional" => ["intensity"]
            },
            item_link_roles: %{
              "roles" => [
                %{
                  "role" => "machine",
                  "item_type_key" => item_types.cardio_machine.key,
                  "required" => true
                },
                %{
                  "role" => "environment",
                  "item_type_key" => item_types.gym_environment.key,
                  "required" => false
                }
              ]
            },
            effect_rules: %{"rules" => []}
          }
        )
    }
  end

  defp install_session_template!(plan, environment, user) do
    create!(:create_session_template!, user, %{
      plan_id: plan.id,
      key: "upper_biased_gym_visit",
      name: "Upper-biased gym visit",
      description: "Two push, two pull, and one cardio choice",
      environment_id: environment.id,
      completion_policy: %{"minimum_completed_slots" => 3},
      missed_policy: %{"kind" => "skip_without_carrying_forward"}
    })
  end

  defp install_session_slots!(plan, session_template, pools, user) do
    [
      create!(
        :create_session_slot!,
        user,
        %{
          plan_id: plan.id,
          session_template_id: session_template.id,
          key: "push",
          name: "Push",
          pool_id: pools.push.id,
          count: 2,
          position: 1
        }
      ),
      create!(
        :create_session_slot!,
        user,
        %{
          plan_id: plan.id,
          session_template_id: session_template.id,
          key: "pull",
          name: "Pull",
          pool_id: pools.pull.id,
          count: 2,
          position: 2
        }
      ),
      create!(
        :create_session_slot!,
        user,
        %{
          plan_id: plan.id,
          session_template_id: session_template.id,
          key: "cardio",
          name: "Cardio",
          pool_id: pools.cardio.id,
          count: 1,
          position: 3
        }
      )
    ]
  end

  defp install_schedule!(plan, session_template, starts_on, user) do
    create!(:create_schedule!, user, %{
      plan_id: plan.id,
      owner_type: :session_template,
      owner_id: session_template.id,
      kind: :times_per_week,
      starts_on: starts_on,
      ends_on: plan.ends_on,
      rules: %{
        "times" => 3,
        "allowed_weekdays" => ["monday", "wednesday", "friday", "saturday"],
        "minimum_gap_days" => 1
      }
    })
  end

  defp item_type!(plan, user, attrs) do
    attrs
    |> Map.put(:plan_id, plan.id)
    |> then(&create!(:create_item_type!, user, &1))
  end

  defp item!(plan, user, item_type, key, name, facts) do
    create!(:create_item!, user, %{
      plan_id: plan.id,
      item_type_id: item_type.id,
      key: key,
      name: name,
      facts: facts
    })
  end

  defp pool!(plan, user, key, name, description) do
    create!(:create_pool!, user, %{
      plan_id: plan.id,
      key: key,
      name: name,
      description: description
    })
  end

  defp pool_membership!(plan, user, pool, item) do
    create!(:create_pool_membership!, user, %{
      plan_id: plan.id,
      pool_id: pool.id,
      item_id: item.id
    })
  end

  defp create!(function, user, attrs) do
    {record, notifications} =
      apply(Plans, function, [
        attrs,
        [actor: user, return_notifications?: true]
      ])

    collect_notifications!(notifications)
    record
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
