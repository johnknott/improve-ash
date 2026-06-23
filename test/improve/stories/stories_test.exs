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

  describe "vial inventory story helpers" do
    test "log a linked inventory event and derive item state from generated effects" do
      story =
        Story.begin!("test_vial_inventory_basic", reset?: true)
        |> Story.user!("Story Vial", email: "story+test-vial-inventory-basic@example.test")

      plan =
        Story.create_plan!(story, "Vial inventory plan",
          intention: "Track vial quantity and dose history",
          from: ~D[2026-06-22],
          until: ~D[2026-09-14]
        )

      Story.add_item_type!(story, plan, "Peptide vial", key: "peptide_vial")

      Story.add_item!(story, plan, "Retatrutide vial 1",
        key: "reta_vial_1",
        type: "peptide_vial",
        stateful: true,
        facts: %{starting_quantity: 5000, unit: "mcg", low_quantity_threshold: 500}
      )

      Story.add_event_type!(story, plan, "Dose taken",
        key: "dose_taken",
        required_links: ["source_vial"],
        payload: %{required: ["amount", "unit"]},
        effects: [
          Story.subtract_quantity(
            from: "source_vial",
            quantity: "payload.amount",
            unit: "payload.unit"
          )
        ]
      )

      before_state =
        capture_return(fn ->
          Story.show_item_state!(story, plan, "reta_vial_1")
        end)

      assert Decimal.equal?(before_state.calculated_state.current_quantity, Decimal.new(5000))
      assert before_state.calculated_state.unit == "mcg"
      assert before_state.active_effects == []

      log =
        Story.log_event!(story, plan,
          event: "dose_taken",
          on: ~D[2026-06-22],
          summary: "Dose taken from Retatrutide vial 1",
          links: %{source_vial: "reta_vial_1"},
          payload: %{amount: 250, unit: "mcg", site: "abdomen", note: "Morning dose"}
        )

      assert log.event.summary == "Dose taken from Retatrutide vial 1"
      assert log.event.quantity == Decimal.new(250)
      assert log.event.unit == "mcg"

      assert [%{role: "source_vial"} = link] = log.event_item_links
      assert [effect] = log.item_effects
      assert effect.item_id == link.item_id
      assert effect.effect_type == :subtract_quantity
      assert effect.quantity == Decimal.new(250)
      assert effect.unit == "mcg"

      after_state =
        capture_return(fn ->
          Story.show_item_state!(story, plan, "reta_vial_1")
        end)

      assert Decimal.equal?(after_state.calculated_state.current_quantity, Decimal.new(4750))
      assert after_state.calculated_state.unit == "mcg"
      assert Enum.map(after_state.active_effects, & &1.id) == [effect.id]
      assert after_state.warnings == []

      assert [%{id: event_id}] = Journal.read_journal!(plan, actor: story.user)
      assert event_id == log.event.id

      ai_state =
        capture_return(fn ->
          Story.show_ai_item_state!(story, plan, "reta_vial_1")
        end)

      assert ai_state.calculated_state.current_quantity == "4750"
      assert [%{effect_type: :subtract_quantity, quantity: "250"}] = ai_state.active_effects
    end
  end

  describe "correction story helpers" do
    test "corrects a logged inventory event while preserving auditable history" do
      story =
        Story.begin!("test_correct_logged_event", reset?: true)
        |> Story.user!("Story Correct", email: "story+test-correct-logged-event@example.test")

      plan = vial_inventory_plan!(story, "Correction inventory plan")

      original =
        Story.log_event!(story, plan,
          event: "dose_taken",
          on: ~D[2026-06-22],
          summary: "Dose taken from Retatrutide vial 1",
          links: %{source_vial: "reta_vial_1"},
          payload: %{amount: 250, unit: "mcg", site: "abdomen"}
        )

      before_state =
        capture_return(fn ->
          Story.show_item_state!(story, plan, "reta_vial_1")
        end)

      assert Decimal.equal?(before_state.calculated_state.current_quantity, Decimal.new(4750))

      correction =
        Story.correct_event!(story, original,
          corrected_at: ~U[2026-06-22 21:00:00Z],
          reason: "Amount was entered incorrectly",
          replacement: [
            event: "dose_taken",
            effective_at: ~U[2026-06-22 20:00:00Z],
            summary: "Corrected dose from Retatrutide vial 1",
            links: %{source_vial: "reta_vial_1"},
            payload: %{amount: 200, unit: "mcg", site: "abdomen"}
          ]
        )

      assert correction.corrected_event.status == :corrected
      assert [voided_effect] = correction.voided_effects
      assert voided_effect.status == :voided
      assert [replacement_effect] = correction.replacement.item_effects
      assert replacement_effect.status == :active
      assert correction.replacement.event.replaces_event_instance_id == original.event.id

      after_state =
        capture_return(fn ->
          Story.show_item_state!(story, plan, "reta_vial_1")
        end)

      assert Decimal.equal?(after_state.calculated_state.current_quantity, Decimal.new(4800))
      assert Enum.map(after_state.active_effects, & &1.id) == [replacement_effect.id]

      assert %{corrected: 1, active: 1} =
               plan
               |> Journal.read_journal!(actor: story.user)
               |> Enum.map(& &1.status)
               |> Enum.frequencies()

      ai_state =
        capture_return(fn ->
          Story.show_ai_item_state!(story, plan, "reta_vial_1")
        end)

      assert ai_state.calculated_state.current_quantity == "4800"
      assert [%{effect_type: :subtract_quantity, quantity: "200"}] = ai_state.active_effects
    end
  end

  describe "offline story helpers" do
    test "deduplicates offline retries and flags stale slot-linked events" do
      story =
        Story.begin!("test_offline_duplicate_and_stale", reset?: true)
        |> Story.user!("Story Offline", email: "story+test-offline@example.test")

      plan = hybrid_today_plan!(story, "Offline resilience plan")
      today = Story.project_today!(story, plan, on: ~D[2026-06-22])
      session = Story.start_session!(story, today, "upper_body")

      reading =
        Story.offline_event(story, plan,
          event: "pages_read",
          goal: "daily_reading",
          on: ~D[2026-06-22],
          summary: "Read 20 pages offline",
          payload: %{pages: 20, note: "Queued while offline"},
          operation: "offline-reading-001",
          client_event_id: "offline-reading-001-event",
          idempotency_key: "offline-reading-001-key"
        )

      logged_slot =
        Story.log_slot!(story, session,
          slot: "push",
          item: "chest_press",
          event: "exercise_performed",
          payload: %{sets: 3, reps: 10}
        )
        |> Map.fetch!(:slot_result)

      stale_slot =
        Story.offline_event(story, plan,
          event: "exercise_performed",
          on: ~D[2026-06-22],
          summary: "Offline chest press retry",
          links: %{exercise: "chest_press"},
          payload: %{sets: 3, reps: 10},
          session_occurrence_id: session.session_occurrence.id,
          slot_result_id: logged_slot.id,
          operation: "offline-slot-001",
          client_event_id: "offline-slot-001-event",
          idempotency_key: "offline-slot-001-key"
        )

      result = Story.submit_offline_events!(story, [reading, reading, stale_slot])

      assert [:accepted, :duplicate, :needs_resolution] =
               Enum.map(result.results, & &1.status)

      [accepted, duplicate, stale] = result.results
      assert duplicate.event_instance_id == accepted.event_instance_id
      assert stale.conflict_category == :stale_session_state

      events = Journal.read_journal!(plan, actor: story.user)
      assert length(events) == 2
      assert accepted.event_instance_id in Enum.map(events, & &1.id)
    end
  end

  describe "hybrid today story helpers" do
    test "projects direct goals and sessions together before and after logging" do
      story =
        Story.begin!("test_hybrid_today", reset?: true)
        |> Story.user!("Story Hybrid", email: "story+test-hybrid@example.test")

      plan = hybrid_today_plan!(story, "Hybrid today plan")

      before = Story.project_today!(story, plan, on: ~D[2026-06-22])
      assert Enum.map(before.projected_work, & &1.kind) == [:session, :direct_goal]
      assert Enum.map(before.projected_work, & &1.status) == [:planned, :planned]

      reading =
        Story.log_direct_goal!(story, before,
          goal: "daily_reading",
          payload: %{pages: 25, note: "Read before breakfast"}
        )

      session = Story.start_session!(story, before, "upper_body")

      slot =
        Story.log_slot!(story, session,
          slot: "push",
          item: "chest_press",
          event: "exercise_performed",
          payload: %{sets: 3, reps: 10}
        )

      after_projection = Story.project_today!(story, plan, on: ~D[2026-06-22])

      assert [
               %{kind: :session, status: :planned},
               %{kind: :direct_goal, status: :completed}
             ] = after_projection.projected_work

      event_ids =
        plan
        |> Journal.read_journal!(actor: story.user)
        |> Enum.map(& &1.id)
        |> MapSet.new()

      assert event_ids == MapSet.new([reading.event.id, slot.event.id])

      ai_context =
        capture_return(fn ->
          Story.show_ai_today_context!(story, plan, on: ~D[2026-06-22])
        end)

      assert [
               %{kind: "session", status: "planned"},
               %{kind: "direct_goal", status: "completed"}
             ] = ai_context.projected_work

      assert ai_context.input_summary.journal_events == 2
      assert ai_context.input_summary.session_occurrences == 1
    end
  end

  defp capture_return(fun) do
    ref = make_ref()

    capture_io(fn ->
      Process.put(ref, fun.())
    end)

    Process.get(ref)
  end

  defp vial_inventory_plan!(story, name) do
    plan =
      Story.create_plan!(story, name,
        intention: "Track vial quantity and dose history",
        from: ~D[2026-06-22],
        until: ~D[2026-09-14]
      )

    Story.add_item_type!(story, plan, "Peptide vial", key: "peptide_vial")

    Story.add_item!(story, plan, "Retatrutide vial 1",
      key: "reta_vial_1",
      type: "peptide_vial",
      stateful: true,
      facts: %{starting_quantity: 5000, unit: "mcg"}
    )

    Story.add_event_type!(story, plan, "Dose taken",
      key: "dose_taken",
      required_links: ["source_vial"],
      payload: %{required: ["amount", "unit"]},
      effects: [
        Story.subtract_quantity(
          from: "source_vial",
          quantity: "payload.amount",
          unit: "payload.unit"
        )
      ]
    )

    plan
  end

  defp hybrid_today_plan!(story, name) do
    plan =
      Story.create_plan!(story, name,
        intention: "See daily goals and gym sessions together",
        from: ~D[2026-06-22],
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

    Story.add_event_type!(story, plan, "Exercise performed",
      key: "exercise_performed",
      required_links: ["exercise"],
      payload: %{required: ["sets", "reps"]}
    )

    Story.add_exercise!(story, plan, "Chest Press", key: "chest_press")
    Story.add_exercise!(story, plan, "Lat Pulldown", key: "lat_pulldown")

    Story.add_pool!(story, plan, "Push exercises", key: "push", items: ["chest_press"])
    Story.add_pool!(story, plan, "Pull exercises", key: "pull", items: ["lat_pulldown"])

    Story.add_session!(story, plan, "Upper body gym visit",
      key: "upper_body",
      schedule: Story.every_week(times: 1, on: [:monday]),
      slots: [
        Story.choose(1, from: "push"),
        Story.choose(1, from: "pull")
      ]
    )

    plan
  end
end
