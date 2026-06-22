defmodule Improve.Planning.ProjectTodayTest do
  use Improve.DataCase, async: true

  alias Improve.Accounts
  alias Improve.Fixtures.GymPlan
  alias Improve.Journal
  alias Improve.Plans
  alias Improve.Sessions

  describe "project_today/2" do
    test "projects today's gym work without mutating the database" do
      user =
        Accounts.create_user!(%{
          email: "project-gym@example.com",
          full_name: "Project Gym"
        })

      %{plan: plan} = GymPlan.install!(user, starts_on: ~D[2026-06-22])

      assert {:ok, []} = Sessions.list_session_occurrences(actor: user)

      assert {:ok, projection} = Plans.project_today(plan, actor: user, date: ~D[2026-06-22])

      assert projection.plan_id == plan.id
      assert projection.date == ~D[2026-06-22]
      assert projection.diagnostics == []
      assert [_explanation] = projection.explanations
      assert projection.input_summary.direct_goals == 0
      assert projection.input_summary.session_templates == 1
      assert projection.input_summary.session_template_schedules == 1

      assert [
               %{
                 session_template_name: "Upper-biased gym visit",
                 planned_for: ~D[2026-06-22],
                 recommendations: recommendations
               }
             ] = projection.projected_session_occurrences

      assert [
               %{
                 kind: :session,
                 status: :planned,
                 owner_type: :session_template,
                 title: "Upper-biased gym visit",
                 planned_for: ~D[2026-06-22],
                 payload: %{
                   session_occurrence: %{
                     session_template_name: "Upper-biased gym visit",
                     recommendations: ^recommendations
                   }
                 }
               }
             ] = projection.projected_work

      recommendation_counts =
        Map.new(recommendations, fn recommendation ->
          {recommendation.slot_key, Enum.map(recommendation.recommended_items, & &1.item_name)}
        end)

      assert %{
               "push" => push_items,
               "pull" => pull_items,
               "cardio" => cardio_items
             } = recommendation_counts

      assert length(push_items) == 2
      assert length(pull_items) == 2
      assert length(cardio_items) == 1
      assert Enum.all?(push_items ++ pull_items ++ cardio_items, &is_binary/1)

      assert {:ok, []} = Sessions.list_session_occurrences(actor: user)
    end

    test "returns no projections outside the plan date range" do
      user =
        Accounts.create_user!(%{
          email: "project-outside@example.com",
          full_name: "Project Outside"
        })

      %{plan: plan} = GymPlan.install!(user, starts_on: ~D[2026-06-22])

      assert {:ok, projection} = Plans.project_today(plan, actor: user, date: ~D[2026-09-01])

      assert projection.projected_session_occurrences == []
      assert projection.projected_work == []
      assert projection.diagnostics == []
      assert projection.explanations == ["No projected work is scheduled for this date."]
      assert {:ok, []} = Sessions.list_session_occurrences(actor: user)
    end

    test "places times-per-week session quotas instead of projecting every allowed weekday" do
      user =
        Accounts.create_user!(%{
          email: "project-quota-gym@example.com",
          full_name: "Project Quota Gym"
        })

      %{plan: plan} = GymPlan.install!(user, starts_on: ~D[2026-06-22])

      assert {:ok, monday} = Plans.project_today(plan, actor: user, date: ~D[2026-06-22])
      assert [_session] = monday.projected_session_occurrences

      assert {:ok, saturday} = Plans.project_today(plan, actor: user, date: ~D[2026-06-27])
      assert saturday.projected_session_occurrences == []
      assert saturday.projected_work == []
      assert saturday.diagnostics == []
    end

    test "projects a scheduled direct goal as planned without mutating history" do
      user =
        Accounts.create_user!(%{
          email: "project-direct-goal-planned@example.com",
          full_name: "Project Direct Goal Planned"
        })

      plan = plan!(user)
      event_type = event_type!(user, plan)
      direct_goal = direct_goal!(user, plan, event_type)
      schedule!(user, plan, direct_goal)

      assert {:ok, []} = Sessions.list_session_occurrences(actor: user)
      assert {:ok, []} = Journal.read_journal(plan, actor: user)

      assert {:ok, projection} = Plans.project_today(plan, actor: user, date: ~D[2026-06-22])

      assert projection.input_summary.direct_goals == 1
      assert projection.input_summary.direct_goal_schedules == 1
      assert projection.input_summary.session_templates == 0
      assert projection.projected_session_occurrences == []

      assert [
               %{
                 kind: :direct_goal,
                 status: :planned,
                 title: "Read 20 pages",
                 planned_for: ~D[2026-06-22],
                 payload: %{
                   direct_goal_id: direct_goal_id,
                   direct_goal_key: "read_twenty_pages",
                   target: %{"quantity" => 20, "unit" => "pages"},
                   completed_event_ids: []
                 }
               }
             ] = projection.projected_work

      assert direct_goal_id == direct_goal.id
      assert projection.diagnostics == []

      assert {:ok, []} = Sessions.list_session_occurrences(actor: user)
      assert {:ok, []} = Journal.read_journal(plan, actor: user)
    end

    test "projects a scheduled direct goal as completed from linked journal history" do
      user =
        Accounts.create_user!(%{
          email: "project-direct-goal-completed@example.com",
          full_name: "Project Direct Goal Completed"
        })

      plan = plan!(user)
      event_type = event_type!(user, plan)
      direct_goal = direct_goal!(user, plan, event_type)
      schedule!(user, plan, direct_goal)

      log =
        Journal.log_generic_event!(
          %{
            plan_id: plan.id,
            event_type_id: event_type.id,
            direct_goal_id: direct_goal.id,
            effective_at: ~U[2026-06-22 20:00:00Z],
            recorded_at: ~U[2026-06-22 20:01:00Z],
            summary: "Read 25 pages",
            quantity: 25,
            unit: "pages",
            payload: %{"amount" => 25, "unit" => "pages"}
          },
          actor: user
        )

      assert {:ok, projection} = Plans.project_today(plan, actor: user, date: ~D[2026-06-22])

      assert [
               %{
                 kind: :direct_goal,
                 status: :completed,
                 payload: %{completed_event_ids: [completed_event_id]}
               }
             ] = projection.projected_work

      assert completed_event_id == log.event.id
      assert [_event] = Journal.read_journal!(plan, actor: user)
      assert {:ok, []} = Sessions.list_session_occurrences(actor: user)
    end

    test "projects a scheduled direct goal as missed when the date has passed without history" do
      user =
        Accounts.create_user!(%{
          email: "project-direct-goal-missed@example.com",
          full_name: "Project Direct Goal Missed"
        })

      plan = plan!(user)
      event_type = event_type!(user, plan)
      direct_goal = direct_goal!(user, plan, event_type)
      schedule!(user, plan, direct_goal)

      assert {:ok, projection} =
               Plans.project_today(plan,
                 actor: user,
                 date: ~D[2026-06-22],
                 as_of_date: ~D[2026-06-23]
               )

      assert [
               %{
                 kind: :direct_goal,
                 status: :missed,
                 payload: %{direct_goal_id: direct_goal_id, completed_event_ids: []}
               }
             ] = projection.projected_work

      assert direct_goal_id == direct_goal.id
      assert {:ok, []} = Journal.read_journal(plan, actor: user)
      assert {:ok, []} = Sessions.list_session_occurrences(actor: user)
    end

    test "counts completed history when placing times-per-week direct goal quota" do
      user =
        Accounts.create_user!(%{
          email: "project-direct-goal-quota@example.com",
          full_name: "Project Direct Goal Quota"
        })

      plan = plan!(user)
      event_type = event_type!(user, plan)
      direct_goal = direct_goal!(user, plan, event_type)
      quota_schedule!(user, plan, direct_goal)

      log =
        Journal.log_generic_event!(
          %{
            plan_id: plan.id,
            event_type_id: event_type.id,
            direct_goal_id: direct_goal.id,
            effective_at: ~U[2026-06-22 20:00:00Z],
            recorded_at: ~U[2026-06-22 20:01:00Z],
            summary: "Read 20 pages",
            quantity: 20,
            unit: "pages"
          },
          actor: user
        )

      assert {:ok, monday} = Plans.project_today(plan, actor: user, date: ~D[2026-06-22])

      assert [
               %{
                 kind: :direct_goal,
                 status: :completed,
                 payload: %{completed_event_ids: [completed_event_id]}
               }
             ] = monday.projected_work

      assert completed_event_id == log.event.id

      assert {:ok, tuesday} = Plans.project_today(plan, actor: user, date: ~D[2026-06-23])
      assert tuesday.projected_work == []

      assert {:ok, wednesday} = Plans.project_today(plan, actor: user, date: ~D[2026-06-24])

      assert [
               %{
                 kind: :direct_goal,
                 status: :planned,
                 payload: %{completed_event_ids: []}
               }
             ] = wednesday.projected_work
    end
  end

  defp plan!(user) do
    Plans.create_plan!(
      %{
        name: "Reading",
        intention: "Track reading",
        starts_on: ~D[2026-06-22],
        ends_on: ~D[2026-07-20]
      },
      actor: user
    )
  end

  defp event_type!(user, plan) do
    Plans.create_event_type!(
      %{
        plan_id: plan.id,
        key: "read_pages",
        name: "Read Pages"
      },
      actor: user
    )
  end

  defp direct_goal!(user, plan, event_type) do
    Plans.create_direct_goal!(
      %{
        plan_id: plan.id,
        event_type_id: event_type.id,
        key: "read_twenty_pages",
        name: "Read 20 pages",
        target: %{"quantity" => 20, "unit" => "pages"},
        completion_policy: %{"mode" => "at_least_target"},
        missed_policy: %{"mode" => "miss_if_no_event_by_end_of_day"}
      },
      actor: user
    )
  end

  defp schedule!(user, plan, direct_goal) do
    Plans.create_schedule!(
      %{
        plan_id: plan.id,
        owner_type: :direct_goal,
        owner_id: direct_goal.id,
        kind: :every_day,
        starts_on: ~D[2026-06-22]
      },
      actor: user
    )
  end

  defp quota_schedule!(user, plan, direct_goal) do
    Plans.create_schedule!(
      %{
        plan_id: plan.id,
        owner_type: :direct_goal,
        owner_id: direct_goal.id,
        kind: :times_per_week,
        rules: %{
          "times" => 2,
          "allowed_weekdays" => ["monday", "tuesday", "wednesday"],
          "minimum_gap_days" => 1
        },
        starts_on: ~D[2026-06-22]
      },
      actor: user
    )
  end
end
