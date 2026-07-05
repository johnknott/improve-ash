defmodule Improve.Planning.ProjectTodayTest do
  use Improve.DataCase, async: true

  alias Improve.Accounts
  alias Improve.Fixtures.GymPlan
  alias Improve.Journal
  alias Improve.Planning.Projector
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

    test "projects multiple dates from one loaded plan snapshot" do
      user =
        Accounts.create_user!(%{
          email: "project-many-dates@example.com",
          full_name: "Project Many Dates"
        })

      %{plan: plan} = GymPlan.install!(user, starts_on: ~D[2026-06-22])
      dates = [~D[2026-06-22], ~D[2026-06-23], ~D[2026-06-24]]

      assert {:ok, batch} =
               Plans.project_dates(plan, dates, actor: user, as_of_date: ~D[2026-06-22])

      individual =
        Enum.map(dates, fn date ->
          Plans.project_today!(plan, actor: user, date: date, as_of_date: ~D[2026-06-22])
        end)

      assert Enum.map(batch, & &1.date) == dates
      assert Enum.map(batch, & &1.projected_work) == Enum.map(individual, & &1.projected_work)
      assert Enum.map(batch, & &1.diagnostics) == Enum.map(individual, & &1.diagnostics)
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

    test "projects selected weekdays only on matching days" do
      monday =
        projector_input(
          schedule: %{
            id: "weekday-schedule",
            kind: :selected_weekdays,
            rules: %{"weekdays" => ["monday", "wednesday"]},
            starts_on: ~D[2026-06-22]
          },
          date: ~D[2026-06-22]
        )
        |> Projector.project_today()

      assert [%{title: "Read 20 pages", planned_for: ~D[2026-06-22]}] = monday.projected_work
      assert monday.diagnostics == []

      tuesday =
        projector_input(
          schedule: %{
            id: "weekday-schedule",
            kind: :selected_weekdays,
            rules: %{"weekdays" => ["monday", "wednesday"]},
            starts_on: ~D[2026-06-22]
          },
          date: ~D[2026-06-23]
        )
        |> Projector.project_today()

      assert tuesday.projected_work == []
      assert tuesday.diagnostics == []
    end

    test "returns diagnostics for malformed every-n-days rules" do
      projection =
        projector_input(
          schedule: %{
            id: "bad-every-n-days",
            kind: :every_n_days,
            rules: %{"interval_days" => "soon"},
            starts_on: ~D[2026-06-22]
          },
          date: ~D[2026-06-22]
        )
        |> Projector.project_today()

      assert projection.projected_work == []

      diagnostic = diagnostic(projection, :unsupported_schedule_rules)
      assert diagnostic.severity == :error
      assert diagnostic.message == "Every-N-days schedules need a positive interval_days rule."
      assert diagnostic.details == %{schedule_id: "bad-every-n-days", value: "soon"}
    end

    test "returns diagnostics for schedule kinds the projector does not recognize" do
      projection =
        projector_input(
          schedule: %{
            id: "moon-phase-schedule",
            kind: :moon_phase,
            rules: %{},
            starts_on: ~D[2026-06-22]
          },
          date: ~D[2026-06-22]
        )
        |> Projector.project_today()

      assert projection.projected_work == []

      diagnostic = diagnostic(projection, :unsupported_schedule_kind)
      assert diagnostic.severity == :warning
      assert diagnostic.message == "Schedule kind is not recognized by the projector."
      assert diagnostic.details == %{schedule_id: "moon-phase-schedule", kind: :moon_phase}
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
                 payload: %{
                   completed_event_ids: [completed_event_id],
                   target_progress: %{
                     completed_event_count: 1,
                     completed_event_ids: [completed_event_id]
                   }
                 }
               }
             ] = projection.projected_work

      assert completed_event_id == log.event.id
      assert [_event] = Journal.read_journal!(plan, actor: user)
      assert {:ok, []} = Sessions.list_session_occurrences(actor: user)
    end

    test "buckets journal events by the user's local day, not UTC" do
      user =
        Accounts.create_user!(%{
          email: "project-track-timezone@example.com",
          full_name: "Project Track Timezone",
          timezone: "America/New_York"
        })

      plan = plan!(user)
      event_type = event_type!(user, plan)
      track = track!(user, plan, event_type)
      schedule!(user, plan, track)

      # 01:30 UTC on June 23 is 21:30 on June 22 in New York.
      Journal.log_generic_event!(
        %{
          plan_id: plan.id,
          event_type_id: event_type.id,
          track_id: track.id,
          effective_at: ~U[2026-06-23 01:30:00Z],
          recorded_at: ~U[2026-06-23 01:31:00Z],
          summary: "Late evening reading",
          quantity: 25,
          unit: "pages",
          payload: %{"amount" => 25, "unit" => "pages"}
        },
        actor: user
      )

      assert {:ok, projection} = Plans.project_today(plan, actor: user, date: ~D[2026-06-22])
      assert [%{kind: :track, status: :completed}] = projection.projected_work

      assert {:ok, next_day} = Plans.project_today(plan, actor: user, date: ~D[2026-06-23])
      assert [%{kind: :track, status: status}] = next_day.projected_work
      assert status != :completed
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

    test "projects a scheduled track as on hold during fully off time off" do
      user =
        Accounts.create_user!(%{
          email: "project-track-time-off@example.com",
          full_name: "Project Track Time Off"
        })

      plan = plan!(user)
      event_type = event_type!(user, plan)
      track = track!(user, plan, event_type)
      schedule!(user, plan, track)

      time_off =
        Plans.create_time_off_window!(
          %{
            plan_id: plan.id,
            key: "summer_holiday",
            kind: :holiday,
            reason: "Summer holiday",
            starts_on: ~D[2026-06-22],
            ends_on: ~D[2026-06-28],
            availability: :fully_off
          },
          actor: user
        )

      assert {:ok, projection} =
               Plans.project_today(plan,
                 actor: user,
                 date: ~D[2026-06-22],
                 as_of_date: ~D[2026-06-23]
               )

      assert projection.input_summary.time_off_windows == 1

      assert [
               %{
                 kind: :track,
                 status: :on_hold,
                 title: "Read 20 pages",
                 payload: %{
                   completed_event_ids: [],
                   time_off_window: %{
                     id: time_off_id,
                     key: "summer_holiday",
                     kind: :holiday,
                     reason: "Summer holiday",
                     starts_on: ~D[2026-06-22],
                     ends_on: ~D[2026-06-28],
                     availability: :fully_off
                   }
                 },
                 explanation: explanation
               }
             ] = projection.projected_work

      assert time_off_id == time_off.id
      assert explanation =~ "On hold"
      assert explanation =~ "Summer holiday"
      assert {:ok, []} = Journal.read_journal(plan, actor: user)
    end

    test "completed track history still wins during time off" do
      user =
        Accounts.create_user!(%{
          email: "project-track-time-off-completed@example.com",
          full_name: "Project Track Time Off Completed"
        })

      plan = plan!(user)
      event_type = event_type!(user, plan)
      track = track!(user, plan, event_type)
      schedule!(user, plan, track)

      Plans.create_time_off_window!(
        %{
          plan_id: plan.id,
          key: "summer_holiday",
          kind: :holiday,
          starts_on: ~D[2026-06-22],
          ends_on: ~D[2026-06-28],
          availability: :fully_off
        },
        actor: user
      )

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
            unit: "pages"
          },
          actor: user
        )

      assert {:ok, projection} = Plans.project_today(plan, actor: user, date: ~D[2026-06-22])

      assert [
               %{
                 status: :completed,
                 payload: %{completed_event_ids: [completed_event_id]}
               }
             ] = projection.projected_work

      assert completed_event_id == log.event.id
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

      diagnostic = diagnostic(projection, :partial_week_schedule)
      assert diagnostic.severity == :info
      assert diagnostic.message =~ "remain this week"
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

    test "returns diagnostics for target types the projector does not recognize" do
      projection =
        projector_input(
          target: %{"type" => "moonshot", "quantity" => 1},
          schedule: %{
            id: "daily-schedule",
            kind: :every_day,
            rules: %{},
            starts_on: ~D[2026-06-22]
          },
          date: ~D[2026-06-22]
        )
        |> Projector.project_today()

      assert [_work] = projection.projected_work

      diagnostic = diagnostic(projection, :unknown_track_target_type)
      assert diagnostic.severity == :warning
      assert diagnostic.message == "This track target type is not recognized."

      assert diagnostic.details == %{
               track_id: "track-1",
               track_key: "read_twenty_pages",
               target_type: "moonshot"
             }
    end

    test "projects a metric target as completed with the recorded value" do
      projection =
        projector_input(
          target: %{
            "type" => "metric",
            "metric" => "Bodyweight",
            "unit" => "kg",
            "quantity_path" => "payload.value"
          },
          schedule: %{
            id: "daily-schedule",
            kind: :every_day,
            rules: %{},
            starts_on: ~D[2026-06-22]
          },
          date: ~D[2026-06-22],
          journal_events: [
            event(%{
              id: "event-1",
              track_id: "track-1",
              payload: %{"value" => 82.5}
            })
          ]
        )
        |> Projector.project_today()

      assert [
               %{
                 status: :completed,
                 payload: %{
                   completed_event_ids: ["event-1"],
                   target_progress: %{
                     recorded_value: 82.5,
                     unit: "kg",
                     label: "Recorded 82.5 kg"
                   }
                 }
               }
             ] = projection.projected_work

      assert projection.diagnostics == []
    end

    test "projects checklist progress across same-day linked events" do
      projection =
        projector_input(
          target: %{"type" => "checklist", "items" => ["Tidy room", "Brush teeth"]},
          schedule: %{
            id: "daily-schedule",
            kind: :every_day,
            rules: %{},
            starts_on: ~D[2026-06-22]
          },
          date: ~D[2026-06-22],
          journal_events: [
            event(%{
              id: "event-1",
              track_id: "track-1",
              payload: %{"completed_items" => ["Tidy room"]}
            }),
            event(%{
              id: "event-2",
              track_id: "track-1",
              payload: %{"completed_items" => ["Brush teeth"]}
            })
          ]
        )
        |> Projector.project_today()

      assert [
               %{
                 status: :completed,
                 payload: %{
                   completed_event_ids: ["event-1", "event-2"],
                   target_progress: %{
                     completed_count: 2,
                     required_count: 2,
                     label: "2 of 2 complete"
                   }
                 }
               }
             ] = projection.projected_work

      assert projection.diagnostics == []
    end

    test "projects period-total progress across the containing week" do
      projection =
        projector_input(
          target: %{
            "type" => "period_total",
            "quantity" => 100,
            "unit" => "pages",
            "per" => "week",
            "quantity_path" => "payload.amount"
          },
          schedule: %{
            id: "daily-schedule",
            kind: :every_day,
            rules: %{},
            starts_on: ~D[2026-06-22]
          },
          date: ~D[2026-06-24],
          journal_events: [
            event(%{id: "event-1", track_id: "track-1", payload: %{"amount" => 40}}),
            event(%{
              id: "event-2",
              track_id: "track-1",
              effective_at: ~U[2026-06-26 20:00:00Z],
              payload: %{"amount" => 60}
            })
          ]
        )
        |> Projector.project_today()

      assert [
               %{
                 status: :completed,
                 payload: %{
                   completed_event_ids: ["event-1", "event-2"],
                   target_progress: %{
                     total_quantity: "100",
                     target_quantity: "100",
                     unit: "pages",
                     period: :week,
                     label: "100 of 100 pages this week"
                   }
                 }
               }
             ] = projection.projected_work

      assert projection.diagnostics == []
    end

    test "projects progression completion against the expected amount for the date" do
      projection =
        projector_input(
          target: %{
            "type" => "progression",
            "from" => 1_000,
            "to" => 10_000,
            "unit" => "steps",
            "quantity_path" => "payload.amount",
            "shape" => "linear"
          },
          schedule: %{
            id: "daily-schedule",
            kind: :every_day,
            rules: %{},
            starts_on: ~D[2026-06-22]
          },
          date: ~D[2026-07-06],
          journal_events: [
            event(%{
              id: "event-1",
              track_id: "track-1",
              effective_at: ~U[2026-07-06 20:00:00Z],
              payload: %{"amount" => 5_500}
            })
          ]
        )
        |> Projector.project_today()

      assert [
               %{
                 status: :completed,
                 payload: %{
                   completed_event_ids: ["event-1"],
                   target_progress: %{
                     total_quantity: "5500",
                     expected_quantity: "5500",
                     unit: "steps",
                     from: "1000",
                     to: "10000",
                     label: "5500 of 5500 steps expected today"
                   }
                 }
               }
             ] = projection.projected_work

      assert projection.diagnostics == []
    end

    test "projects adaptive completion from configured fields" do
      projection =
        projector_input(
          target: %{
            "type" => "adaptive",
            "fields" => ["sets", "reps", "load"],
            "effort" => "effort"
          },
          schedule: %{
            id: "daily-schedule",
            kind: :every_day,
            rules: %{},
            starts_on: ~D[2026-06-22]
          },
          date: ~D[2026-06-22],
          journal_events: [
            event(%{
              id: "event-1",
              track_id: "track-1",
              payload: %{"sets" => 3, "reps" => 10, "load" => 45, "effort" => "steady"}
            })
          ]
        )
        |> Projector.project_today()

      assert [
               %{
                 status: :completed,
                 payload: %{
                   completed_event_ids: ["event-1"],
                   target_progress: %{
                     required_fields: ["sets", "reps", "load", "effort"],
                     recorded_fields: ["sets", "reps", "load", "effort"],
                     missing_fields: [],
                     label: "4 of 4 adaptive fields recorded"
                   }
                 }
               }
             ] = projection.projected_work

      assert projection.diagnostics == []
    end

    test "projects monthly tracks on the configured day" do
      projection =
        projector_input(
          schedule: %{
            id: "monthly-schedule",
            kind: :monthly,
            rules: %{"day" => 15},
            starts_on: ~D[2026-06-22]
          },
          date: ~D[2026-07-15]
        )
        |> Projector.project_today()

      assert [%{kind: :track, title: "Read 20 pages"}] = projection.projected_work
      assert projection.diagnostics == []

      not_due =
        projector_input(
          schedule: %{
            id: "monthly-schedule",
            kind: :monthly,
            rules: %{"day" => 15},
            starts_on: ~D[2026-06-22]
          },
          date: ~D[2026-07-16]
        )
        |> Projector.project_today()

      assert not_due.projected_work == []
      assert not_due.diagnostics == []
    end

    test "projects monthly schedules on the last day of shorter months" do
      projection =
        projector_input(
          schedule: %{
            id: "monthly-schedule",
            kind: :monthly,
            rules: %{"day" => 31},
            starts_on: ~D[2026-06-22]
          },
          date: ~D[2026-06-30]
        )
        |> Projector.project_today()

      assert [%{kind: :track, title: "Read 20 pages"}] = projection.projected_work
      assert projection.diagnostics == []
    end

    test "projects monthly session templates" do
      projection =
        projector_input(
          schedule: %{
            id: "monthly-session-schedule",
            kind: :monthly,
            rules: %{"day" => 15},
            starts_on: ~D[2026-06-22],
            owner_type: :session_template,
            owner_id: "template-1"
          },
          date: ~D[2026-07-15],
          tracks: [],
          session_templates: [
            %{
              id: "template-1",
              key: "monthly_review",
              plan_id: "plan-1",
              name: "Monthly review",
              environment_id: nil
            }
          ]
        )
        |> Projector.project_today()

      assert [
               %{
                 kind: :session,
                 title: "Monthly review",
                 planned_for: ~D[2026-07-15]
               }
             ] = projection.projected_work

      assert projection.diagnostics == []
    end

    test "returns diagnostics for malformed monthly schedules" do
      projection =
        projector_input(
          schedule: %{
            id: "bad-monthly",
            kind: :monthly,
            rules: %{"day" => 32},
            starts_on: ~D[2026-06-22]
          },
          date: ~D[2026-07-20]
        )
        |> Projector.project_today()

      assert projection.projected_work == []

      diagnostic = diagnostic(projection, :unsupported_schedule_rules)
      assert diagnostic.severity == :error
      assert diagnostic.message == "Monthly schedules need a day rule between 1 and 31."
      assert diagnostic.details == %{schedule_id: "bad-monthly", value: 32}
    end

    test "projects every-N-weeks tracks on selected weekdays in matching weeks" do
      projection =
        projector_input(
          schedule: %{
            id: "every-two-weeks",
            kind: :every_n_weeks,
            rules: %{"interval_weeks" => 2, "weekdays" => ["monday", "friday"]},
            starts_on: ~D[2026-06-22]
          },
          date: ~D[2026-07-06]
        )
        |> Projector.project_today()

      assert [%{kind: :track, title: "Read 20 pages"}] = projection.projected_work
      assert projection.diagnostics == []

      off_week =
        projector_input(
          schedule: %{
            id: "every-two-weeks",
            kind: :every_n_weeks,
            rules: %{"interval_weeks" => 2, "weekdays" => ["monday", "friday"]},
            starts_on: ~D[2026-06-22]
          },
          date: ~D[2026-06-29]
        )
        |> Projector.project_today()

      assert off_week.projected_work == []
      assert off_week.diagnostics == []

      off_weekday =
        projector_input(
          schedule: %{
            id: "every-two-weeks",
            kind: :every_n_weeks,
            rules: %{"interval_weeks" => 2, "weekdays" => ["monday", "friday"]},
            starts_on: ~D[2026-06-22]
          },
          date: ~D[2026-07-07]
        )
        |> Projector.project_today()

      assert off_weekday.projected_work == []
      assert off_weekday.diagnostics == []
    end

    test "projects every-N-weeks session templates" do
      projection =
        projector_input(
          schedule: %{
            id: "every-two-weeks-session",
            kind: :every_n_weeks,
            rules: %{"interval_weeks" => 2, "weekdays" => ["monday"]},
            starts_on: ~D[2026-06-22],
            owner_type: :session_template,
            owner_id: "template-1"
          },
          date: ~D[2026-07-06],
          tracks: [],
          session_templates: [
            %{
              id: "template-1",
              key: "fortnightly_review",
              plan_id: "plan-1",
              name: "Fortnightly review",
              environment_id: nil
            }
          ]
        )
        |> Projector.project_today()

      assert [
               %{
                 kind: :session,
                 title: "Fortnightly review",
                 planned_for: ~D[2026-07-06]
               }
             ] = projection.projected_work

      assert projection.diagnostics == []
    end

    test "returns diagnostics for malformed every-N-weeks schedules" do
      projection =
        projector_input(
          schedule: %{
            id: "bad-every-n-weeks",
            kind: :every_n_weeks,
            rules: %{"interval_weeks" => 0, "weekdays" => ["monday"]},
            starts_on: ~D[2026-06-22]
          },
          date: ~D[2026-07-06]
        )
        |> Projector.project_today()

      assert projection.projected_work == []

      diagnostic = diagnostic(projection, :unsupported_schedule_rules)
      assert diagnostic.severity == :error
      assert diagnostic.message == "Every-N-weeks schedules need a positive interval_weeks rule."
      assert diagnostic.details == %{schedule_id: "bad-every-n-weeks", value: 0}
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
      diagnostic = diagnostic(projection, :unsatisfiable_schedule_rules)
      assert diagnostic.severity == :warning
      assert diagnostic.message =~ "only fit 1"
      assert diagnostic.details.placed == 1
      assert diagnostic.details.structural_maximum == 1
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
        kind: :after_completion,
        rules: %{"days" => 2},
        starts_on: ~D[2026-06-22]
      },
      actor: user
    )
  end

  defp diagnostic(projection, code) do
    Enum.find(projection.diagnostics, &(&1.code == code)) ||
      flunk("Expected diagnostic #{inspect(code)} in #{inspect(projection.diagnostics)}")
  end

  defp projector_input(opts) do
    plan = %{
      id: "plan-1",
      starts_on: ~D[2026-06-22],
      ends_on: ~D[2026-07-20]
    }

    track = %{
      id: "track-1",
      plan_id: plan.id,
      event_type_id: "event-type-1",
      key: "read_twenty_pages",
      name: "Read 20 pages",
      target: Keyword.get(opts, :target, %{"quantity" => 20, "unit" => "pages"}),
      completion_policy: %{"mode" => "at_least_target"},
      missed_policy: %{"mode" => "miss_if_no_event_by_end_of_day"}
    }

    schedule =
      Map.merge(
        %{
          id: "schedule-1",
          kind: :every_day,
          rules: %{},
          starts_on: ~D[2026-06-22],
          plan_id: plan.id,
          owner_type: :track,
          owner_id: track.id,
          ends_on: nil
        },
        Keyword.fetch!(opts, :schedule)
      )

    schedule =
      Map.merge(
        %{
          plan_id: plan.id,
          owner_type: :track,
          owner_id: track.id,
          ends_on: nil
        },
        schedule
      )

    %{
      date: Keyword.fetch!(opts, :date),
      plan: plan,
      session_templates: Keyword.get(opts, :session_templates, []),
      session_slots: [],
      schedules: [schedule],
      tracks: Keyword.get(opts, :tracks, [track]),
      journal_events: Keyword.get(opts, :journal_events, []),
      session_occurrences: [],
      slot_results: [],
      items: [],
      pool_memberships: [],
      environments: [],
      time_off_windows: Keyword.get(opts, :time_off_windows, [])
    }
  end

  defp event(attrs) do
    Map.merge(
      %{
        id: "event-1",
        track_id: "track-1",
        status: :active,
        effective_at: ~U[2026-06-22 20:00:00Z],
        quantity: nil,
        unit: nil,
        payload: %{}
      },
      attrs
    )
  end
end
