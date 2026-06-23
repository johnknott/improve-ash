defmodule Improve.StoriesTest do
  use Improve.DataCase, async: true

  import ExUnit.CaptureIO

  alias Improve.Journal
  alias Improve.Plans
  alias Improve.Sessions
  alias Improve.Stories, as: Story

  describe "direct goal story helpers" do
    test "express a reading goal product story through the headless domains" do
      story =
        Story.begin!("test_direct_goal_reading", reset?: true)
        |> Story.user!("Story Reader", email: "story+test-direct-goal-reading@example.test")

      plan =
        Story.create_plan!(story, "Read more consistently",
          intention: "Read a little every day",
          from: ~D[2026-06-23],
          until: ~D[2026-07-23]
        )

      Story.add_event_type!(story, plan, "Pages read",
        key: "pages_read",
        payload: %{required: ["pages"]}
      )

      Story.add_direct_goal!(story, plan, "Read 20 pages",
        key: "daily_reading",
        event: "pages_read",
        schedule: Story.every_day(),
        target: %{
          quantity: 20,
          unit: "pages",
          quantity_path: "payload.pages",
          summary_template: "Read %{quantity} %{unit}"
        }
      )

      summary =
        capture_return(fn ->
          Story.show_plan_summary!(story, plan)
        end)

      assert summary.direct_goals == 1
      assert summary.event_types == 1

      today = Story.project_today!(story, plan, on: ~D[2026-06-23])

      assert [
               %{
                 kind: :direct_goal,
                 status: :planned,
                 title: "Read 20 pages"
               }
             ] = today.projected_work

      log =
        Story.log_direct_goal!(story, today,
          goal: "daily_reading",
          payload: %{pages: 25, note: "Read before bed"}
        )

      assert log.event.summary == "Read 25 pages"
      assert log.event.quantity == Decimal.new(25)
      assert log.event.unit == "pages"
      assert log.event.note == "Read before bed"

      assert [%{id: event_id, direct_goal_id: direct_goal_id}] =
               Journal.read_journal!(plan, actor: story.user)

      assert event_id == log.event.id
      assert direct_goal_id == log.event.direct_goal_id

      ai_context =
        capture_return(fn ->
          Story.show_ai_today_context!(story, plan, on: ~D[2026-06-23])
        end)

      assert [
               %{
                 kind: "direct_goal",
                 status: "completed",
                 direct_goal: %{completed_event_ids: [^event_id]}
               }
             ] = ai_context.projected_work

      reset_story =
        Story.begin!("test_direct_goal_reading", reset?: true)
        |> Story.user!("Story Reader", email: "story+test-direct-goal-reading@example.test")

      assert Plans.list_plans!(actor: reset_story.user) == []
    end
  end

  describe "gym session story helpers" do
    test "express a projected gym session with a completed slot and a swap" do
      story =
        Story.begin!("test_gym_session_basic", reset?: true)
        |> Story.user!("Story Gym", email: "story+test-gym-session-basic@example.test")

      plan =
        Story.create_plan!(story, "Gym starter plan",
          intention: "Build a consistent upper body routine",
          from: ~D[2026-06-22],
          until: ~D[2026-07-23]
        )

      Story.add_event_type!(story, plan, "Exercise performed",
        key: "exercise_performed",
        required_links: ["exercise"],
        payload: %{required: ["sets", "reps", "load", "load_unit"]}
      )

      Story.add_exercise!(story, plan, "Chest Press", key: "chest_press")
      Story.add_exercise!(story, plan, "Shoulder Press", key: "shoulder_press")
      Story.add_exercise!(story, plan, "Lat Pulldown", key: "lat_pulldown")
      Story.add_exercise!(story, plan, "Seated Row", key: "seated_row")
      Story.add_exercise!(story, plan, "Cable Fly", key: "cable_fly")

      Story.add_pool!(story, plan, "Push exercises",
        key: "push",
        items: ["chest_press", "shoulder_press"]
      )

      Story.add_pool!(story, plan, "Pull exercises",
        key: "pull",
        items: ["lat_pulldown", "seated_row"]
      )

      Story.add_session!(story, plan, "Upper body gym visit",
        key: "upper_body",
        schedule: Story.every_week(times: 2, on: [:monday, :thursday]),
        slots: [
          Story.choose(2, from: "push"),
          Story.choose(2, from: "pull")
        ]
      )

      today = Story.project_today!(story, plan, on: ~D[2026-06-22])

      assert [
               %{
                 kind: :session,
                 title: "Upper body gym visit",
                 payload: %{session_occurrence: projected_session}
               }
             ] = today.projected_work

      assert [
               %{slot_key: "push", recommended_items: push_items},
               %{slot_key: "pull", recommended_items: pull_items}
             ] = projected_session.recommendations

      assert Enum.map(push_items, & &1.item_key) == ["chest_press", "shoulder_press"]
      assert Enum.map(pull_items, & &1.item_key) == ["lat_pulldown", "seated_row"]

      session = Story.start_session!(story, today, "upper_body")
      assert %{session_occurrence: occurrence, slot_results: slot_results} = session
      assert occurrence.status == :started
      assert length(slot_results) == 4

      first_log =
        Story.log_slot!(story, session,
          slot: "push",
          item: "chest_press",
          event: "exercise_performed",
          payload: %{sets: 3, reps: 10, load: 45, load_unit: "kg"},
          note: "Felt solid"
        )

      swap_log =
        Story.log_slot!(story, session,
          slot: "push",
          recommended: "shoulder_press",
          actual: "cable_fly",
          event: "exercise_performed",
          payload: %{sets: 3, reps: 12, load: 20, load_unit: "kg"},
          note: "Station was busy"
        )

      assert first_log.event.summary == "Chest Press performed"
      assert first_log.slot_result.status == :completed
      assert swap_log.event.summary == "Cable Fly performed instead of Shoulder Press"
      assert swap_log.slot_result.status == :swapped

      slot_statuses =
        Sessions.list_slot_results!(
          actor: story.user,
          query: [filter: [session_occurrence_id: occurrence.id]]
        )
        |> Enum.map(& &1.status)
        |> Enum.frequencies()

      assert slot_statuses.completed == 1
      assert slot_statuses.swapped == 1
      assert slot_statuses.planned == 2

      assert [first_event, swap_event] = Journal.read_journal!(plan, actor: story.user)
      assert first_event.session_occurrence_id == occurrence.id
      assert swap_event.session_occurrence_id == occurrence.id
      assert first_event.slot_result_id == first_log.slot_result.id
      assert swap_event.slot_result_id == swap_log.slot_result.id

      ai_context =
        capture_return(fn ->
          Story.show_ai_today_context!(story, plan, on: ~D[2026-06-22])
        end)

      assert [
               %{
                 kind: "session",
                 status: "planned",
                 session_occurrence: %{session_template_name: "Upper body gym visit"}
               }
             ] = ai_context.projected_work
    end
  end

  defp capture_return(fun) do
    ref = make_ref()

    capture_io(fn ->
      Process.put(ref, fun.())
    end)

    Process.get(ref)
  end
end
