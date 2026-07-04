defmodule Improve.SessionsJournalTest do
  use Improve.DataCase, async: true

  alias Improve.Accounts
  alias Improve.Journal
  alias Improve.Plans
  alias Improve.Sessions

  describe "sessions and journal records" do
    test "a session occurrence can preserve recommendations and link to journal facts" do
      user = user!("session-author@example.com")
      plan = plan!(user)

      %{event_type: event_type, item: exercise, pool: pool} = authored_content!(user, plan)

      session_template =
        Plans.create_session_template!(
          %{
            plan_id: plan.id,
            key: "upper_gym",
            name: "Upper-biased gym visit",
            description: "A simple strength session",
            completion_policy: %{"minimum_completed_slots" => 3}
          },
          actor: user
        )

      session_slot =
        Plans.create_session_slot!(
          %{
            plan_id: plan.id,
            session_template_id: session_template.id,
            key: "push",
            name: "Push exercise",
            pool_id: pool.id,
            count: 2,
            position: 1
          },
          actor: user
        )

      occurrence =
        Sessions.create_session_occurrence!(
          %{
            plan_id: plan.id,
            session_template_id: session_template.id,
            planned_for: ~D[2026-06-22],
            recommendation_snapshot: %{
              "slots" => [
                %{"slot_key" => "push", "recommended_item_key" => "chest_press"}
              ]
            }
          },
          actor: user
        )

      slot_result =
        Sessions.create_slot_result!(
          %{
            plan_id: plan.id,
            session_occurrence_id: occurrence.id,
            session_slot_id: session_slot.id,
            recommended_item_id: exercise.id,
            actual_item_id: exercise.id
          },
          actor: user
        )

      event =
        Journal.log_event!(
          %{
            plan_id: plan.id,
            event_type_id: event_type.id,
            session_occurrence_id: occurrence.id,
            slot_result_id: slot_result.id,
            effective_at: ~U[2026-06-22 12:00:00Z],
            recorded_at: ~U[2026-06-22 12:05:00Z],
            summary: "Chest Press completed",
            quantity: Decimal.new("3"),
            unit: "sets",
            payload: %{"reps" => [8, 8, 7]}
          },
          actor: user
        )

      link =
        Journal.create_event_item_link!(
          %{
            plan_id: plan.id,
            event_instance_id: event.id,
            item_id: exercise.id,
            role: "exercise"
          },
          actor: user
        )

      effect =
        Journal.create_item_effect!(
          %{
            plan_id: plan.id,
            item_id: exercise.id,
            event_instance_id: event.id,
            effect_type: :set_fact,
            payload: %{"last_completed_at" => "2026-06-22T12:00:00Z"}
          },
          actor: user
        )

      completed_slot =
        Sessions.complete_slot_result!(
          slot_result,
          %{
            actual_item_id: exercise.id,
            event_instance_id: event.id,
            notes: "Matched recommendation"
          },
          actor: user
        )

      completed_occurrence =
        Sessions.complete_session_occurrence!(
          occurrence,
          %{
            completed_at: ~U[2026-06-22 13:00:00Z],
            feedback: %{"effort" => "steady"}
          },
          actor: user
        )

      assert completed_occurrence.status == :completed
      assert completed_slot.status == :completed
      assert completed_slot.event_instance_id == event.id
      assert link.role == "exercise"
      assert effect.status == :active

      assert {:ok, [listed_event]} = Journal.list_events(actor: user)
      assert listed_event.id == event.id
    end

    test "runtime and journal reads are scoped through plan ownership" do
      owner = user!("session-owner@example.com")
      other_user = user!("session-other@example.com")
      plan = plan!(owner)

      %{event_type: event_type} = authored_content!(owner, plan)

      session_template =
        Plans.create_session_template!(
          %{
            plan_id: plan.id,
            key: "private_session",
            name: "Private session"
          },
          actor: owner
        )

      occurrence =
        Sessions.create_session_occurrence!(
          %{
            plan_id: plan.id,
            session_template_id: session_template.id,
            planned_for: ~D[2026-06-22]
          },
          actor: owner
        )

      event =
        Journal.log_event!(
          %{
            plan_id: plan.id,
            event_type_id: event_type.id,
            effective_at: ~U[2026-06-22 12:00:00Z],
            recorded_at: ~U[2026-06-22 12:05:00Z],
            summary: "Private event"
          },
          actor: owner
        )

      assert {:ok, []} = Sessions.list_session_occurrences(actor: other_user)
      assert {:ok, []} = Journal.list_events(actor: other_user)

      assert {:error, %Ash.Error.Invalid{}} =
               Sessions.get_session_occurrence(occurrence.id, actor: other_user)

      assert {:error, %Ash.Error.Invalid{}} = Journal.get_event(event.id, actor: other_user)

      assert {:error, %Ash.Error.Forbidden{}} =
               Sessions.create_session_occurrence(
                 %{
                   plan_id: plan.id,
                   session_template_id: session_template.id,
                   planned_for: ~D[2026-06-23]
                 },
                 actor: other_user
               )
    end

    test "resource actions reject terminal state rewrites" do
      user = user!("session-transition@example.com")
      plan = plan!(user)
      %{event_type: event_type, item: exercise, pool: pool} = authored_content!(user, plan)

      session_template =
        Plans.create_session_template!(
          %{
            plan_id: plan.id,
            key: "transition_session",
            name: "Transition session"
          },
          actor: user
        )

      session_slot =
        Plans.create_session_slot!(
          %{
            plan_id: plan.id,
            session_template_id: session_template.id,
            key: "transition_slot",
            name: "Transition slot",
            pool_id: pool.id
          },
          actor: user
        )

      occurrence =
        Sessions.create_session_occurrence!(
          %{
            plan_id: plan.id,
            session_template_id: session_template.id,
            planned_for: ~D[2026-06-22]
          },
          actor: user
        )

      slot_result =
        Sessions.create_slot_result!(
          %{
            plan_id: plan.id,
            session_occurrence_id: occurrence.id,
            session_slot_id: session_slot.id,
            recommended_item_id: exercise.id,
            actual_item_id: exercise.id
          },
          actor: user
        )

      event =
        Journal.log_event!(
          %{
            plan_id: plan.id,
            event_type_id: event_type.id,
            session_occurrence_id: occurrence.id,
            slot_result_id: slot_result.id,
            effective_at: ~U[2026-06-22 12:00:00Z],
            recorded_at: ~U[2026-06-22 12:05:00Z],
            summary: "Transition event"
          },
          actor: user
        )

      effect =
        Journal.create_item_effect!(
          %{
            plan_id: plan.id,
            item_id: exercise.id,
            event_instance_id: event.id,
            effect_type: :set_fact,
            payload: %{"transition" => true}
          },
          actor: user
        )

      completed_occurrence =
        Sessions.complete_session_occurrence!(
          occurrence,
          %{completed_at: ~U[2026-06-22 13:00:00Z]},
          actor: user
        )

      completed_slot =
        Sessions.complete_slot_result!(
          slot_result,
          %{actual_item_id: exercise.id, event_instance_id: event.id},
          actor: user
        )

      voided_event =
        Journal.void_event!(
          event,
          %{voided_at: ~U[2026-06-22 13:05:00Z]},
          actor: user
        )

      voided_effect =
        Journal.void_item_effect!(
          effect,
          %{voided_at: ~U[2026-06-22 13:05:00Z]},
          actor: user
        )

      assert {:error, %Ash.Error.Invalid{}} =
               Sessions.start_session_occurrence(
                 completed_occurrence,
                 %{started_at: ~U[2026-06-22 13:10:00Z]},
                 actor: user
               )

      assert {:error, %Ash.Error.Invalid{}} =
               Sessions.swap_slot_result(
                 completed_slot,
                 %{actual_item_id: exercise.id, event_instance_id: event.id},
                 actor: user
               )

      assert {:error, %Ash.Error.Invalid{}} =
               Journal.mark_event_corrected(
                 voided_event,
                 %{voided_at: ~U[2026-06-22 13:10:00Z]},
                 actor: user
               )

      assert {:error, %Ash.Error.Invalid{}} =
               Journal.void_item_effect(
                 voided_effect,
                 %{voided_at: ~U[2026-06-22 13:10:00Z]},
                 actor: user
               )
    end
  end

  describe "projection of swapped slots" do
    test "a swapped slot with a logged event counts toward session completion" do
      user = user!("session-swap-projection@example.com")
      plan = plan!(user)

      %{event_type: event_type, item: recommended, pool: pool} = authored_content!(user, plan)

      alternate =
        Plans.create_item!(
          %{
            plan_id: plan.id,
            item_type_id: recommended.item_type_id,
            key: "incline_press",
            name: "Incline Press"
          },
          actor: user
        )

      Plans.create_pool_membership!(
        %{plan_id: plan.id, pool_id: pool.id, item_id: alternate.id},
        actor: user
      )

      session_template =
        Plans.create_session_template!(
          %{
            plan_id: plan.id,
            key: "swap_gym",
            name: "Swap-friendly gym visit"
          },
          actor: user
        )

      session_slot =
        Plans.create_session_slot!(
          %{
            plan_id: plan.id,
            session_template_id: session_template.id,
            key: "push",
            name: "Push exercise",
            pool_id: pool.id,
            count: 1,
            position: 1
          },
          actor: user
        )

      Plans.create_schedule!(
        %{
          plan_id: plan.id,
          owner_type: :session_template,
          owner_id: session_template.id,
          kind: :every_n_days,
          starts_on: ~D[2026-06-22],
          ends_on: plan.ends_on,
          rules: %{"interval_days" => 1}
        },
        actor: user
      )

      occurrence =
        Sessions.create_session_occurrence!(
          %{
            plan_id: plan.id,
            session_template_id: session_template.id,
            planned_for: ~D[2026-06-22],
            status: :started
          },
          actor: user
        )

      slot_result =
        Sessions.create_slot_result!(
          %{
            plan_id: plan.id,
            session_occurrence_id: occurrence.id,
            session_slot_id: session_slot.id,
            recommended_item_id: recommended.id
          },
          actor: user
        )

      event =
        Journal.log_event!(
          %{
            plan_id: plan.id,
            event_type_id: event_type.id,
            session_occurrence_id: occurrence.id,
            slot_result_id: slot_result.id,
            effective_at: ~U[2026-06-22 12:00:00Z],
            recorded_at: ~U[2026-06-22 12:05:00Z],
            summary: "Incline Press instead of Chest Press"
          },
          actor: user
        )

      swapped_slot =
        Sessions.swap_slot_result!(
          slot_result,
          %{
            actual_item_id: alternate.id,
            event_instance_id: event.id,
            notes: "Machine was taken"
          },
          actor: user
        )

      assert swapped_slot.status == :swapped
      assert swapped_slot.event_instance_id == event.id

      assert {:ok, projection} = Plans.project_today(plan, actor: user, date: ~D[2026-06-22])

      assert [%{kind: :session, status: :completed, payload: %{session_state: session_state}}] =
               projection.projected_work

      assert session_state.slot_results_total == 1
      assert session_state.slot_results_logged == 1
    end
  end

  defp user!(email) do
    Accounts.create_user!(%{
      email: email,
      full_name: "Test User"
    })
  end

  defp plan!(user) do
    Plans.create_plan!(
      %{
        name: "Runtime test plan",
        intention: "Prove runtime records",
        starts_on: ~D[2026-06-22],
        ends_on: ~D[2026-07-20]
      },
      actor: user
    )
  end

  defp authored_content!(user, plan) do
    item_type =
      Plans.create_item_type!(
        %{
          plan_id: plan.id,
          key: "exercise",
          name: "Exercise"
        },
        actor: user
      )

    item =
      Plans.create_item!(
        %{
          plan_id: plan.id,
          item_type_id: item_type.id,
          key: "chest_press",
          name: "Chest Press"
        },
        actor: user
      )

    pool =
      Plans.create_pool!(
        %{
          plan_id: plan.id,
          key: "push",
          name: "Push exercises"
        },
        actor: user
      )

    Plans.create_pool_membership!(
      %{
        plan_id: plan.id,
        pool_id: pool.id,
        item_id: item.id
      },
      actor: user
    )

    event_type =
      Plans.create_event_type!(
        %{
          plan_id: plan.id,
          key: "workout_set",
          name: "Workout set performed"
        },
        actor: user
      )

    %{event_type: event_type, item: item, pool: pool}
  end
end
