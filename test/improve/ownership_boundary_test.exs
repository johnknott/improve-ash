defmodule Improve.OwnershipBoundaryTest do
  use Improve.DataCase, async: true

  alias Improve.Accounts
  alias Improve.CommandError
  alias Improve.Fixtures.GymPlan
  alias Improve.Fixtures.VialPlan
  alias Improve.Journal
  alias Improve.Plans
  alias Improve.Sessions

  describe "cross-user ownership boundaries" do
    test "public workflow helpers do not expose another user's plan data" do
      owner = user!("ownership-owner@example.com", "Ownership Owner")
      other_user = user!("ownership-other@example.com", "Ownership Other")

      %{plan: gym_plan} = GymPlan.install!(owner, starts_on: ~D[2026-06-22])

      assert {:ok, []} = Plans.list_plans(actor: other_user)
      assert {:error, %Ash.Error.Invalid{}} = Plans.get_plan(gym_plan.id, actor: other_user)
      assert {:error, %Ash.Error.Invalid{}} = Plans.summarize_plan(gym_plan, actor: other_user)

      assert {:error, %Ash.Error.Invalid{}} =
               Plans.project_today(gym_plan, actor: other_user, date: ~D[2026-06-22])

      owner_projection = Plans.project_today!(gym_plan, actor: owner, date: ~D[2026-06-22])
      [projected_occurrence] = owner_projection.projected_session_occurrences

      assert_forbidden(fn ->
        Sessions.start_projected_session!(
          projected_occurrence,
          actor: other_user,
          started_at: ~U[2026-06-22 12:00:00Z]
        )
      end)

      %{plan: vial_plan} = VialPlan.install!(owner, starts_on: ~D[2026-06-22])

      items =
        Plans.list_items!(actor: owner, query: [filter: [plan_id: vial_plan.id]])
        |> Map.new(&{&1.key, &1})

      event_types =
        Plans.list_event_types!(actor: owner, query: [filter: [plan_id: vial_plan.id]])
        |> Map.new(&{&1.key, &1})

      original =
        Journal.log_linked_item_event!(
          %{
            plan: vial_plan,
            event_type: event_types["take_dose"],
            linked_item: items["retatrutide_vial_1"],
            role: "source_vial",
            quantity: 250,
            unit: "mcg",
            effective_at: ~U[2026-06-22 08:00:00Z],
            recorded_at: ~U[2026-06-22 08:01:00Z]
          },
          actor: owner
        )

      assert {:error, %Ash.Error.Invalid{}} = Journal.read_journal(vial_plan, actor: other_user)

      assert {:error, %Ash.Error.Invalid{}} =
               Journal.get_item_state(items["retatrutide_vial_1"], actor: other_user)

      assert_forbidden(fn ->
        Journal.log_linked_item_event!(
          %{
            plan: vial_plan,
            event_type: event_types["take_dose"],
            linked_item: items["retatrutide_vial_1"],
            role: "source_vial",
            quantity: 250,
            unit: "mcg",
            effective_at: ~U[2026-06-22 09:00:00Z],
            recorded_at: ~U[2026-06-22 09:01:00Z]
          },
          actor: other_user
        )
      end)

      [original_effect] = original.item_effects

      assert_forbidden(fn ->
        Journal.correct_linked_item_event!(
          %{
            plan: vial_plan,
            event_type: event_types["take_dose"],
            linked_item: items["retatrutide_vial_1"],
            role: "source_vial",
            original_event: original.event,
            original_effect: original_effect,
            quantity: 300,
            unit: "mcg",
            effective_at: ~U[2026-06-22 08:00:00Z],
            recorded_at: ~U[2026-06-22 08:05:00Z],
            corrected_at: ~U[2026-06-22 08:05:00Z]
          },
          actor: other_user
        )
      end)

      assert {:ok, []} = Journal.list_events(actor: other_user)
      assert {:ok, []} = Sessions.list_session_occurrences(actor: other_user)
    end
  end

  defp user!(email, name) do
    Accounts.create_user!(%{
      email: email,
      full_name: name
    })
  end

  defp assert_forbidden(fun) do
    fun.()
    flunk("expected forbidden ownership boundary")
  rescue
    error in [CommandError] ->
      assert error.category == :forbidden
  end
end
