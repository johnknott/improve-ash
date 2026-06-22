defmodule Improve.SessionsJournalSamePlanIntegrityTest do
  use Improve.DataCase, async: true

  alias Improve.Accounts
  alias Improve.Journal
  alias Improve.Plans
  alias Improve.Sessions

  describe "same-plan integrity for session writes" do
    test "session occurrences cannot use a template from another owned plan" do
      user = user!("same-plan-runtime-occurrence@example.com")
      %{plan: plan_a} = fixture!(user, "a")
      %{session_template: template_b} = fixture!(user, "b")

      assert_same_plan_error(fn ->
        Sessions.create_session_occurrence(
          %{
            plan_id: plan_a.id,
            session_template_id: template_b.id,
            planned_for: ~D[2026-06-22]
          },
          actor: user
        )
      end)
    end

    test "slot results cannot mix occurrences, slots, items, or events across plans" do
      user = user!("same-plan-runtime-slot@example.com")
      a = fixture!(user, "a")
      b = fixture!(user, "b")
      occurrence_a = occurrence!(user, a)
      occurrence_b = occurrence!(user, b)
      event_b = event!(user, b)

      assert_same_plan_error(fn ->
        Sessions.create_slot_result(
          %{
            plan_id: a.plan.id,
            session_occurrence_id: occurrence_b.id,
            session_slot_id: a.session_slot.id,
            recommended_item_id: a.item.id
          },
          actor: user
        )
      end)

      assert_same_plan_error(fn ->
        Sessions.create_slot_result(
          %{
            plan_id: a.plan.id,
            session_occurrence_id: occurrence_a.id,
            session_slot_id: b.session_slot.id,
            recommended_item_id: a.item.id
          },
          actor: user
        )
      end)

      assert_same_plan_error(fn ->
        Sessions.create_slot_result(
          %{
            plan_id: a.plan.id,
            session_occurrence_id: occurrence_a.id,
            session_slot_id: a.session_slot.id,
            recommended_item_id: b.item.id
          },
          actor: user
        )
      end)

      assert_same_plan_error(fn ->
        Sessions.create_slot_result(
          %{
            plan_id: a.plan.id,
            session_occurrence_id: occurrence_a.id,
            session_slot_id: a.session_slot.id,
            recommended_item_id: a.item.id,
            actual_item_id: b.item.id
          },
          actor: user
        )
      end)

      assert_same_plan_error(fn ->
        Sessions.create_slot_result(
          %{
            plan_id: a.plan.id,
            session_occurrence_id: occurrence_a.id,
            session_slot_id: a.session_slot.id,
            recommended_item_id: a.item.id,
            event_instance_id: event_b.id
          },
          actor: user
        )
      end)
    end

    test "slot result completion cannot attach foreign actual items or events" do
      user = user!("same-plan-runtime-slot-update@example.com")
      a = fixture!(user, "a")
      b = fixture!(user, "b")
      slot_result_a = slot_result!(user, a)
      event_b = event!(user, b)

      assert_same_plan_error(fn ->
        Sessions.complete_slot_result(
          slot_result_a,
          %{actual_item_id: b.item.id},
          actor: user
        )
      end)

      assert_same_plan_error(fn ->
        Sessions.complete_slot_result(
          slot_result_a,
          %{event_instance_id: event_b.id},
          actor: user
        )
      end)
    end
  end

  describe "same-plan integrity for journal writes" do
    test "events cannot mix event types, planned work, direct goals, or replacements across plans" do
      user = user!("same-plan-runtime-event@example.com")
      a = fixture!(user, "a")
      b = fixture!(user, "b")
      occurrence_a = occurrence!(user, a)
      slot_result_a = slot_result!(user, a)
      occurrence_b = occurrence!(user, b)
      slot_result_b = slot_result!(user, b)
      direct_goal_b = direct_goal!(user, b)
      event_b = event!(user, b)

      assert_same_plan_error(fn ->
        Journal.log_event(event_attrs(a.plan, b.event_type), actor: user)
      end)

      assert_same_plan_error(fn ->
        Journal.log_event(
          event_attrs(a.plan, a.event_type, session_occurrence_id: occurrence_b.id),
          actor: user
        )
      end)

      assert_same_plan_error(fn ->
        Journal.log_event(
          event_attrs(a.plan, a.event_type, slot_result_id: slot_result_b.id),
          actor: user
        )
      end)

      assert_same_plan_error(fn ->
        Journal.log_event(
          event_attrs(a.plan, a.event_type, direct_goal_id: direct_goal_b.id),
          actor: user
        )
      end)

      assert_same_plan_error(fn ->
        Journal.log_event(
          event_attrs(a.plan, a.event_type, replaces_event_instance_id: event_b.id),
          actor: user
        )
      end)

      assert {:ok, event} =
               Journal.log_event(
                 event_attrs(a.plan, a.event_type,
                   session_occurrence_id: occurrence_a.id,
                   slot_result_id: slot_result_a.id
                 ),
                 actor: user
               )

      assert event.plan_id == a.plan.id
    end

    test "event item links cannot mix events and items across plans" do
      user = user!("same-plan-runtime-link@example.com")
      a = fixture!(user, "a")
      b = fixture!(user, "b")
      event_a = event!(user, a)
      event_b = event!(user, b)

      assert_same_plan_error(fn ->
        Journal.create_event_item_link(
          %{
            plan_id: a.plan.id,
            event_instance_id: event_b.id,
            item_id: a.item.id,
            role: "item"
          },
          actor: user
        )
      end)

      assert_same_plan_error(fn ->
        Journal.create_event_item_link(
          %{
            plan_id: a.plan.id,
            event_instance_id: event_a.id,
            item_id: b.item.id,
            role: "item"
          },
          actor: user
        )
      end)
    end

    test "item effects cannot mix items, events, or replacement effects across plans" do
      user = user!("same-plan-runtime-effect@example.com")
      a = fixture!(user, "a")
      b = fixture!(user, "b")
      event_a = event!(user, a)
      event_b = event!(user, b)
      effect_b = effect!(user, b, event_b)

      assert_same_plan_error(fn ->
        Journal.create_item_effect(
          %{
            plan_id: a.plan.id,
            item_id: b.item.id,
            event_instance_id: event_a.id,
            effect_type: :set_fact,
            payload: %{}
          },
          actor: user
        )
      end)

      assert_same_plan_error(fn ->
        Journal.create_item_effect(
          %{
            plan_id: a.plan.id,
            item_id: a.item.id,
            event_instance_id: event_b.id,
            effect_type: :set_fact,
            payload: %{}
          },
          actor: user
        )
      end)

      assert_same_plan_error(fn ->
        Journal.create_item_effect(
          %{
            plan_id: a.plan.id,
            item_id: a.item.id,
            event_instance_id: event_a.id,
            effect_type: :set_fact,
            replaces_item_effect_id: effect_b.id,
            payload: %{}
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
      full_name: "Runtime Same Plan Tester"
    })
  end

  defp fixture!(user, suffix) do
    plan =
      Plans.create_plan!(
        %{
          name: "Runtime #{suffix}",
          intention: "Prove runtime same-plan integrity",
          starts_on: ~D[2026-06-22],
          ends_on: ~D[2026-07-20]
        },
        actor: user
      )

    item_type =
      Plans.create_item_type!(
        %{plan_id: plan.id, key: "item_#{suffix}", name: "Item #{suffix}"},
        actor: user
      )

    item =
      Plans.create_item!(
        %{plan_id: plan.id, item_type_id: item_type.id, key: "thing_#{suffix}", name: "Thing"},
        actor: user
      )

    pool =
      Plans.create_pool!(
        %{plan_id: plan.id, key: "pool_#{suffix}", name: "Pool #{suffix}"},
        actor: user
      )

    Plans.create_pool_membership!(
      %{plan_id: plan.id, pool_id: pool.id, item_id: item.id},
      actor: user
    )

    event_type =
      Plans.create_event_type!(
        %{plan_id: plan.id, key: "event_#{suffix}", name: "Event #{suffix}"},
        actor: user
      )

    session_template =
      Plans.create_session_template!(
        %{plan_id: plan.id, key: "session_#{suffix}", name: "Session #{suffix}"},
        actor: user
      )

    session_slot =
      Plans.create_session_slot!(
        %{
          plan_id: plan.id,
          session_template_id: session_template.id,
          pool_id: pool.id,
          key: "slot_#{suffix}",
          name: "Slot #{suffix}"
        },
        actor: user
      )

    %{
      plan: plan,
      item: item,
      event_type: event_type,
      session_template: session_template,
      session_slot: session_slot
    }
  end

  defp direct_goal!(user, fixture) do
    Plans.create_direct_goal!(
      %{
        plan_id: fixture.plan.id,
        event_type_id: fixture.event_type.id,
        key: "goal",
        name: "Goal"
      },
      actor: user
    )
  end

  defp occurrence!(user, fixture) do
    Sessions.create_session_occurrence!(
      %{
        plan_id: fixture.plan.id,
        session_template_id: fixture.session_template.id,
        planned_for: ~D[2026-06-22]
      },
      actor: user
    )
  end

  defp slot_result!(user, fixture) do
    occurrence = occurrence!(user, fixture)

    Sessions.create_slot_result!(
      %{
        plan_id: fixture.plan.id,
        session_occurrence_id: occurrence.id,
        session_slot_id: fixture.session_slot.id,
        recommended_item_id: fixture.item.id
      },
      actor: user
    )
  end

  defp event!(user, fixture) do
    Journal.log_event!(event_attrs(fixture.plan, fixture.event_type), actor: user)
  end

  defp effect!(user, fixture, event) do
    Journal.create_item_effect!(
      %{
        plan_id: fixture.plan.id,
        item_id: fixture.item.id,
        event_instance_id: event.id,
        effect_type: :set_fact,
        payload: %{}
      },
      actor: user
    )
  end

  defp event_attrs(plan, event_type, extra \\ []) do
    %{
      plan_id: plan.id,
      event_type_id: event_type.id,
      effective_at: ~U[2026-06-22 12:00:00Z],
      recorded_at: ~U[2026-06-22 12:01:00Z],
      summary: "Runtime event"
    }
    |> Map.merge(Map.new(extra))
  end
end
