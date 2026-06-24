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
      assert projection.input_summary.tracks == 0
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

    test "projects a scheduled track as planned without mutating history" do
      user =
        Accounts.create_user!(%{
          email: "project-track-planned@example.com",
          full_name: "Project Track Planned"
        })

      plan = plan!(user)
      event_type = event_type!(user, plan)
      track = track!(user, plan, event_type)
      schedule!(user, plan, track)

      assert {:ok, []} = Sessions.list_session_occurrences(actor: user)
      assert {:ok, []} = Journal.read_journal(plan, actor: user)

      assert {:ok, projection} = Plans.project_today(plan, actor: user, date: ~D[2026-06-22])

      assert projection.input_summary.tracks == 1
      assert projection.input_summary.track_schedules == 1
      assert projection.input_summary.session_templates == 0
      assert projection.projected_session_occurrences == []

      assert [
               %{
                 kind: :track,
                 status: :planned,
                 title: "Read 20 pages",
                 planned_for: ~D[2026-06-22],
                 payload: %{
                   track_id: track_id,
                   track_key: "read_twenty_pages",
                   target: %{"quantity" => 20, "unit" => "pages"},
                   completed_event_ids: []
                 }
               }
             ] = projection.projected_work

      assert track_id == track.id
      assert projection.diagnostics == []

      assert {:ok, []} = Sessions.list_session_occurrences(actor: user)
      assert {:ok, []} = Journal.read_journal(plan, actor: user)
    end

    test "projects a scheduled track as completed from linked journal history" do
      user =
        Accounts.create_user!(%{
          email: "project-track-completed@example.com",
          full_name: "Project Track Completed"
        })

      plan = plan!(user)
      event_type = event_type!(user, plan)
      track = track!(user, plan, event_type)
      schedule!(user, plan, track)

      log =
        Journal.log_generic_event!(
          %{
            plan_id: plan.id,
            event_type_id: event_type.id,
            track_id: track.id,
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
                 kind: :track,
                 status: :completed,
                 payload: %{completed_event_ids: [completed_event_id]}
               }
             ] = projection.projected_work

      assert completed_event_id == log.event.id
      assert [_event] = Journal.read_journal!(plan, actor: user)
      assert {:ok, []} = Sessions.list_session_occurrences(actor: user)
    end

    test "projects a scheduled track as missed when the date has passed without history" do
      user =
        Accounts.create_user!(%{
          email: "project-track-missed@example.com",
          full_name: "Project Track Missed"
        })

      plan = plan!(user)
      event_type = event_type!(user, plan)
      track = track!(user, plan, event_type)
      schedule!(user, plan, track)

      assert {:ok, projection} =
               Plans.project_today(plan,
                 actor: user,
                 date: ~D[2026-06-22],
                 as_of_date: ~D[2026-06-23]
               )

      assert [
               %{
                 kind: :track,
                 status: :missed,
                 payload: %{track_id: track_id, completed_event_ids: []}
               }
             ] = projection.projected_work

      assert track_id == track.id
      assert {:ok, []} = Journal.read_journal(plan, actor: user)
      assert {:ok, []} = Sessions.list_session_occurrences(actor: user)
    end

    test "counts completed history when placing times-per-week track quota" do
      user =
        Accounts.create_user!(%{
          email: "project-track-quota@example.com",
          full_name: "Project Track Quota"
        })

      plan = plan!(user)
      event_type = event_type!(user, plan)
      track = track!(user, plan, event_type)
      quota_schedule!(user, plan, track)

      log =
        Journal.log_generic_event!(
          %{
            plan_id: plan.id,
            event_type_id: event_type.id,
            track_id: track.id,
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
                 kind: :track,
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
                 kind: :track,
                 status: :planned,
                 payload: %{completed_event_ids: []}
               }
             ] = wednesday.projected_work
    end

    test "flows missed earlier weekly quota to remaining allowed days" do
      user =
        Accounts.create_user!(%{
          email: "project-track-quota-forward@example.com",
          full_name: "Project Track Quota Forward"
        })

      plan = plan!(user)
      event_type = event_type!(user, plan)
      track = track!(user, plan, event_type)

      quota_schedule!(user, plan, track,
        rules: %{
          "times" => 2,
          "allowed_weekdays" => ["monday", "wednesday", "friday"],
          "minimum_gap_days" => 1
        }
      )

      assert {:ok, wednesday} =
               Plans.project_today(plan,
                 actor: user,
                 date: ~D[2026-06-24],
                 as_of_date: ~D[2026-06-24]
               )

      assert [
               %{
                 kind: :track,
                 status: :planned,
                 planned_for: ~D[2026-06-24]
               }
             ] = wednesday.projected_work

      assert {:ok, friday} =
               Plans.project_today(plan,
                 actor: user,
                 date: ~D[2026-06-26],
                 as_of_date: ~D[2026-06-24]
               )

      assert [
               %{
                 kind: :track,
                 status: :planned,
                 planned_for: ~D[2026-06-26]
               }
             ] = friday.projected_work
    end

    test "returns diagnostics for an impossible quota schedule" do
      user =
        Accounts.create_user!(%{
          email: "project-impossible-quota@example.com",
          full_name: "Project Impossible Quota"
        })

      plan = plan!(user)
      event_type = event_type!(user, plan)
      track = track!(user, plan, event_type)

      quota_schedule!(user, plan, track,
        rules: %{"times" => 1, "allowed_weekdays" => ["sunday"]},
        ends_on: ~D[2026-06-26]
      )

      assert {:ok, projection} = Plans.project_today(plan, actor: user, date: ~D[2026-06-22])

      assert projection.projected_work == []
      assert diagnostic(projection, :unplaceable_schedule).message =~ "cannot place any work"
    end

    test "returns diagnostics for a missing track target" do
      user =
        Accounts.create_user!(%{
          email: "project-missing-target@example.com",
          full_name: "Project Missing Target"
        })

      plan = plan!(user)
      event_type = event_type!(user, plan)
      track = track_without_target!(user, plan, event_type)
      schedule!(user, plan, track)

      assert {:ok, projection} = Plans.project_today(plan, actor: user, date: ~D[2026-06-22])

      assert [_work] = projection.projected_work
      assert diagnostic(projection, :missing_track_target).message =~ "has no target"
    end

    test "returns diagnostics for recognized schedule kinds that are not projected yet" do
      user =
        Accounts.create_user!(%{
          email: "project-unsupported-schedule@example.com",
          full_name: "Project Unsupported Schedule"
        })

      plan = plan!(user)
      event_type = event_type!(user, plan)
      track = track!(user, plan, event_type)
      unsupported_schedule!(user, plan, track)

      assert {:ok, projection} = Plans.project_today(plan, actor: user, date: ~D[2026-06-22])

      assert projection.projected_work == []

      assert diagnostic(projection, :recognized_unsupported_schedule_kind).message =~
               "recognized, but projection support is not implemented yet"
    end

    test "returns diagnostics when quota rules are only partially placeable" do
      user =
        Accounts.create_user!(%{
          email: "project-partial-quota@example.com",
          full_name: "Project Partial Quota"
        })

      plan = plan!(user)
      event_type = event_type!(user, plan)
      track = track!(user, plan, event_type)

      quota_schedule!(user, plan, track,
        rules: %{
          "times" => 3,
          "allowed_weekdays" => ["monday", "tuesday", "wednesday"],
          "minimum_gap_days" => 2
        }
      )

      assert {:ok, projection} = Plans.project_today(plan, actor: user, date: ~D[2026-06-22])

      assert [_work] = projection.projected_work
      diagnostic = diagnostic(projection, :partially_placeable_schedule)
      assert diagnostic.message =~ "can only place 1 of 3"
      assert diagnostic.details.placed == 1
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

  defp track!(user, plan, event_type) do
    Plans.create_track!(
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

  defp track_without_target!(user, plan, event_type) do
    Plans.create_track!(
      %{
        plan_id: plan.id,
        event_type_id: event_type.id,
        key: "read_any_pages",
        name: "Read pages"
      },
      actor: user
    )
  end

  defp schedule!(user, plan, track) do
    Plans.create_schedule!(
      %{
        plan_id: plan.id,
        owner_type: :track,
        owner_id: track.id,
        kind: :every_day,
        starts_on: ~D[2026-06-22]
      },
      actor: user
    )
  end

  defp quota_schedule!(user, plan, track, opts \\ []) do
    Plans.create_schedule!(
      %{
        plan_id: plan.id,
        owner_type: :track,
        owner_id: track.id,
        kind: :times_per_week,
        rules:
          Keyword.get(opts, :rules, %{
            "times" => 2,
            "allowed_weekdays" => ["monday", "tuesday", "wednesday"],
            "minimum_gap_days" => 1
          }),
        starts_on: ~D[2026-06-22],
        ends_on: Keyword.get(opts, :ends_on)
      },
      actor: user
    )
  end

  defp unsupported_schedule!(user, plan, track) do
    Plans.create_schedule!(
      %{
        plan_id: plan.id,
        owner_type: :track,
        owner_id: track.id,
        kind: :monthly,
        rules: %{"day" => 15},
        starts_on: ~D[2026-06-22]
      },
      actor: user
    )
  end

  defp diagnostic(projection, code) do
    Enum.find(projection.diagnostics, &(&1.code == code)) ||
      flunk("Expected diagnostic #{inspect(code)} in #{inspect(projection.diagnostics)}")
  end
end
