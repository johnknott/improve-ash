defmodule Improve.Fixtures.VialPlan do
  @moduledoc """
  Installs the vial inventory demo plan used by product story tests and local demos.

  This fixture models inventory tracking only. It does not provide medical
  advice or dosing guidance.
  """

  alias Improve.CommandError
  alias Improve.Plans
  alias Improve.Repo

  @twelve_weeks 12 * 7
  @notifications_key {__MODULE__, :notifications}

  def install!(user, opts) do
    CommandError.wrap!(:install_vial_demo_plan, fn ->
      starts_on = Keyword.fetch!(opts, :starts_on)

      Repo.transaction(fn ->
        reset_notifications!()

        plan =
          create!(:create_plan!, user, %{
            name: "Retatrutide Inventory",
            intention: "Track vial quantity and dose history",
            starts_on: starts_on,
            ends_on: Date.add(starts_on, @twelve_weeks),
            status: :active,
            source_kind: :demo,
            source_key: "vial_inventory"
          })

        item_types = install_item_types!(plan, user)
        items = install_items!(plan, item_types, user)
        event_type = install_event_type!(plan, item_types, user)

        result = %{
          plan: plan,
          item_types: item_types,
          items: items,
          event_type: event_type
        }

        {result, take_notifications!()}
      end)
      |> case do
        {:ok, {result, notifications}} ->
          Ash.Notifier.notify(notifications)
          result

        {:error, error} ->
          CommandError.raise!(:install_vial_demo_plan, error)
      end
    end)
  end

  defp install_item_types!(plan, user) do
    %{
      peptide_vial:
        item_type!(plan, user, %{
          key: "peptide_vial",
          name: "Peptide Vial",
          description: "A vial tracked as inventory",
          facts_schema: %{
            "required" => ["compound", "starting_quantity", "unit"],
            "optional" => [
              "prepared_volume",
              "prepared_volume_unit",
              "concentration",
              "concentration_unit",
              "low_quantity_threshold"
            ]
          },
          display_hints: %{"kind" => "inventory"}
        }),
      injection_site:
        item_type!(plan, user, %{
          key: "injection_site",
          name: "Injection Site",
          description: "A body site label for tracking history",
          facts_schema: %{"optional" => ["type"]},
          display_hints: %{"kind" => "site"}
        })
    }
  end

  defp install_items!(plan, item_types, user) do
    %{
      retatrutide_vial_1:
        item!(plan, user, item_types.peptide_vial, "retatrutide_vial_1", "Retatrutide vial 1", %{
          "compound" => "Retatrutide",
          "starting_quantity" => 5000,
          "unit" => "mcg",
          "prepared_volume" => 2,
          "prepared_volume_unit" => "ml",
          "concentration" => 2500,
          "concentration_unit" => "mcg_per_ml",
          "low_quantity_threshold" => 500
        }),
      abdomen:
        item!(plan, user, item_types.injection_site, "abdomen", "Abdomen", %{
          "type" => "injection site"
        })
    }
  end

  defp install_event_type!(plan, item_types, user) do
    create!(:create_event_type!, user, %{
      plan_id: plan.id,
      key: "take_dose",
      name: "Take Dose",
      description: "Record an inventory dose event",
      payload_schema: %{
        "required" => ["amount", "unit"],
        "optional" => ["route", "site", "subjective_feedback", "notes"]
      },
      item_link_roles: %{
        "roles" => [
          %{
            "role" => "source_vial",
            "item_type_key" => item_types.peptide_vial.key,
            "required" => true
          },
          %{
            "role" => "site",
            "item_type_key" => item_types.injection_site.key,
            "required" => false
          }
        ]
      },
      effect_rules: %{
        "rules" => [
          %{
            "role" => "source_vial",
            "effect_type" => "subtract_quantity",
            "quantity_path" => "payload.amount",
            "unit_path" => "payload.unit"
          }
        ]
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
      facts: facts,
      stateful: true
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
