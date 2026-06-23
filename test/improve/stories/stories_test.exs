defmodule Improve.StoriesTest do
  use Improve.DataCase, async: true

  import ExUnit.CaptureIO

  alias Improve.Journal
  alias Improve.Plans
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

  defp capture_return(fun) do
    ref = make_ref()

    capture_io(fn ->
      Process.put(ref, fun.())
    end)

    Process.get(ref)
  end
end
