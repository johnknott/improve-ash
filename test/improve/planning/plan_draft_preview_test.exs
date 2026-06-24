defmodule Improve.Planning.PlanDraftPreviewTest do
  use Improve.DataCase, async: true

  alias Improve.Accounts
  alias Improve.Fixtures.GymPlan
  alias Improve.Plans

  describe "preview_plan_draft/1" do
    test "previews a valid exported draft with counts and readable lists" do
      user =
        Accounts.create_user!(%{
          email: "preview-gym@example.com",
          full_name: "Preview Gym"
        })

      %{plan: plan} = GymPlan.install!(user, starts_on: ~D[2026-06-22])
      draft = Plans.export_plan_draft!(plan, actor: user)

      preview = Plans.preview_plan_draft(draft)

      assert preview.valid?
      assert preview.diagnostics == []
      assert preview.plan.name == "General Fitness"
      assert preview.plan.intention == "Build consistent gym progress"
      assert preview.date_range == %{starts_on: "2026-06-22", ends_on: "2026-08-17"}

      assert preview.counts == %{
               item_types: 3,
               items: 8,
               pools: 3,
               environments: 1,
               event_types: 2,
               session_templates: 1,
               session_slots: 3,
               tracks: 0,
               schedules: 1,
               sample_events: 0
             }

      assert [
               %{
                 key: "upper_biased_gym_visit",
                 name: "Upper-biased gym visit",
                 slots: slots
               }
             ] = preview.lists.sessions

      assert Enum.map(slots, & &1.key) == ["push", "pull", "cardio"]

      assert Enum.any?(
               preview.lists.items,
               &(&1.key == "chest_press" and &1.item_type_key == "exercise")
             )

      assert Enum.map(preview.lists.event_types, & &1.key) == [
               "cardio_block_performed",
               "workout_exercise_performed"
             ]
    end

    test "previews invalid drafts with diagnostics and partial counts" do
      draft = %{
        key: "bad",
        name: "Bad Draft",
        starts_on: "2026-06-22",
        ends_on: "2026-07-20",
        items: [%{key: "orphan", name: "Orphan", item_type_key: "missing_type"}],
        tracks: [
          %{
            key: "read",
            name: "Read",
            event_type_key: "missing_event_type",
            target: %{"quantity" => 20}
          }
        ]
      }

      preview = Plans.preview_plan_draft(draft)

      refute preview.valid?
      assert preview.counts.items == 1
      assert preview.counts.tracks == 1
      assert Enum.any?(preview.diagnostics, &(&1.code == :missing_item_type))
      assert Enum.any?(preview.diagnostics, &(&1.code == :missing_event_type))
      assert Enum.any?(preview.diagnostics, &(&1.code == :track_target_unit_missing))

      assert [%{key: "read", target: %{"quantity" => 20}}] = preview.lists.tracks
    end
  end
end
