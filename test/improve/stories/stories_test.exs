defmodule Improve.StoriesTest do
  use Improve.DataCase, async: true

  import ExUnit.CaptureIO

  alias Improve.Journal
  alias Improve.Plans
  alias Improve.Sessions
  alias Improve.Stories, as: Story

  describe "track story helpers" do
    test "express a reading track product story through the headless domains" do
      story =
        Story.begin!("test_track_reading", reset?: true)
        |> Story.user!("Story Reader", email: "story+test-track-reading@example.test")

      plan =
        Story.create_plan!(story, "Read more consistently",
          intention: "Read a little every day",
          from: ~D[2026-06-23],
          until: ~D[2026-07-23]
        )

      Story.add_track!(story, plan, "Read 20 pages",
        key: "daily_reading",
        schedule: Story.every_day(),
        target: Story.fixed(20, "pages"),
        records: Story.number("pages")
      )

      summary =
        capture_return(fn ->
          Story.show_plan_summary!(story, plan)
        end)

      assert summary.tracks == 1
      assert summary.event_types == 1

      today = Story.project_today!(story, plan, on: ~D[2026-06-23])

      assert [
               %{
                 kind: :track,
                 status: :planned,
                 title: "Read 20 pages"
               }
             ] = today.projected_work

      log =
        Story.log_track!(story, today,
          track: "daily_reading",
          payload: %{amount: 25, note: "Read before bed"}
        )

      assert log.event.summary == "25 pages for Read 20 pages"
      assert log.event.quantity == Decimal.new(25)
      assert log.event.unit == "pages"
      assert log.event.note == "Read before bed"

      event_type = Plans.get_event_type!(log.event.event_type_id, actor: story.user)
      assert event_type.key == "daily_reading_logged"
      assert event_type.payload_schema["required"] == ["amount"]

      assert [%{id: event_id, track_id: track_id}] =
               Journal.read_journal!(plan, actor: story.user)

      assert event_id == log.event.id
      assert track_id == log.event.track_id

      ai_context =
        capture_return(fn ->
          Story.show_ai_today_context!(story, plan, on: ~D[2026-06-23])
        end)

      assert [
               %{
                 kind: "track",
                 status: "completed",
                 track: %{completed_event_ids: [^event_id]}
               }
             ] = ai_context.projected_work

      reset_story =
        Story.begin!("test_track_reading", reset?: true)
        |> Story.user!("Story Reader", email: "story+test-track-reading@example.test")

      assert Plans.list_plans!(actor: reset_story.user) == []
    end

    test "express target constructors through story helpers" do
      story =
        Story.begin!("test_track_target_types", reset?: true)
        |> Story.user!("Story Targets", email: "story+test-track-target-types@example.test")

      plan =
        Story.create_plan!(story, "Try track targets",
          intention: "See target vocabulary",
          from: ~D[2026-06-23],
          until: ~D[2026-07-23]
        )

      Story.add_track!(story, plan, "Reading",
        key: "reading",
        schedule: Story.every_day(),
        target: Story.fixed(20, "pages"),
        records: Story.number("pages")
      )

      Story.add_track!(story, plan, "Bodyweight",
        key: "bodyweight",
        schedule: Story.every_day(),
        target: Story.metric("Bodyweight", unit: "kg"),
        records: Story.amount("kg")
      )

      today = Story.project_today!(story, plan, on: ~D[2026-06-23])

      assert today.projected_work |> Enum.map(& &1.title) |> Enum.sort() == [
               "Bodyweight",
               "Reading"
             ]

      assert Enum.any?(today.diagnostics, &(&1.code == :unsupported_track_target_type))
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

      Story.add_item_type!(story, plan, "Exercise", key: "exercise")
      Story.add_item!(story, plan, "Chest Press", key: "chest_press", type: "exercise")
      Story.add_item!(story, plan, "Shoulder Press", key: "shoulder_press", type: "exercise")
      Story.add_item!(story, plan, "Lat Pulldown", key: "lat_pulldown", type: "exercise")
      Story.add_item!(story, plan, "Seated Row", key: "seated_row", type: "exercise")
      Story.add_item!(story, plan, "Cable Fly", key: "cable_fly", type: "exercise")

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

      journal_by_summary =
        plan
        |> Journal.read_journal!(actor: story.user)
        |> Map.new(&{&1.summary, &1})

      assert %{
               "Chest Press performed" => first_event,
               "Cable Fly performed instead of Shoulder Press" => swap_event
             } = journal_by_summary

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
                 status: "partial",
                 session_occurrence: %{session_template_name: "Upper body gym visit"},
                 session_state: %{progress_label: "2 of 4 logged"}
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
          track: "daily_reading",
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
    test "projects tracks and sessions together before and after logging" do
      story =
        Story.begin!("test_hybrid_today", reset?: true)
        |> Story.user!("Story Hybrid", email: "story+test-hybrid@example.test")

      plan = hybrid_today_plan!(story, "Hybrid today plan")

      before = Story.project_today!(story, plan, on: ~D[2026-06-22])
      assert Enum.map(before.projected_work, & &1.kind) == [:session, :track]
      assert Enum.map(before.projected_work, & &1.status) == [:planned, :planned]

      reading =
        Story.log_track!(story, before,
          track: "daily_reading",
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
               %{kind: :session, status: :partial},
               %{kind: :track, status: :completed}
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
               %{kind: "session", status: "partial"},
               %{kind: "track", status: "completed"}
             ] = ai_context.projected_work

      assert ai_context.input_summary.journal_events == 2
      assert ai_context.input_summary.session_occurrences == 1
      assert ai_context.headline =~ "1 track(s) and 1 session(s)"
      assert Enum.map(ai_context.sections, & &1.kind) == [:sessions, :recovery]
    end
  end

  describe "rough old-plan translation story helpers" do
    test "recreates the old real plan shape without building an importer" do
      story =
        Story.begin!("test_translated_old_plan_rough", reset?: true)
        |> Story.user!("Story Old Plan", email: "story+test-translated-old-plan@example.test")

      plan = translated_old_plan_rough!(story)

      summary =
        capture_return(fn ->
          Story.show_plan_summary!(story, plan)
        end)

      assert summary.items == 10
      assert summary.event_types == 6
      assert summary.tracks == 11
      assert summary.session_templates == 2
      assert summary.schedules == 13

      before_state =
        capture_return(fn ->
          Story.show_item_state!(story, plan, "retatrutide")
        end)

      assert Decimal.equal?(before_state.calculated_state.current_quantity, Decimal.new(20))
      assert before_state.calculated_state.unit == "mg"

      monday = Story.project_today!(story, plan, on: ~D[2026-06-22])
      assert projected_titles(monday, :session) == []
      assert "Retatrutide" in projected_titles(monday, :track)
      assert "Daily habits" in projected_titles(monday, :track)
      assert "Reading" in projected_titles(monday, :track)
      assert "Steps" in projected_titles(monday, :track)

      dose =
        Story.log_event!(story, plan,
          event: "dose_taken",
          track: "retatrutide_dose",
          on: ~D[2026-06-22],
          summary: "Took 2 mg Retatrutide",
          links: %{source_vial: "retatrutide"},
          payload: %{amount: 2, unit: "mg", site: "abdomen"}
        )

      assert dose.event.track_id
      assert dose.event.quantity == Decimal.new(2)
      assert dose.event.unit == "mg"
      assert [%{role: "source_vial"}] = dose.event_item_links

      assert [%{effect_type: :subtract_quantity, quantity: quantity, unit: "mg"}] =
               dose.item_effects

      assert Decimal.equal?(quantity, Decimal.new(2))

      after_state =
        capture_return(fn ->
          Story.show_item_state!(story, plan, "retatrutide")
        end)

      assert Decimal.equal?(after_state.calculated_state.current_quantity, Decimal.new(18))

      assert [%{id: event_id, track_id: track_id}] =
               Journal.read_journal!(plan, actor: story.user)

      assert event_id == dose.event.id
      assert track_id == dose.event.track_id

      monday_after = Story.project_today!(story, plan, on: ~D[2026-06-22])
      assert work_status(monday_after, "Retatrutide") == :completed

      tuesday = Story.project_today!(story, plan, on: ~D[2026-06-23])
      assert projected_titles(tuesday, :session) == ["Upper body gym visit"]
      assert "Cycling" in projected_titles(tuesday, :track)
      assert "Measure waist" in projected_titles(tuesday, :track)
      assert "Listen to music or audiobook" in projected_titles(tuesday, :track)

      assert [
               %{
                 session_template_name: "Upper body gym visit",
                 recommendations: upper_recommendations
               }
             ] = tuesday.projected_session_occurrences

      assert Enum.map(upper_recommendations, & &1.slot_key) == [
               "upper_cardio",
               "upper_push",
               "upper_pull",
               "upper_shoulders"
             ]

      ai_tuesday =
        capture_return(fn ->
          Story.show_ai_today_context!(story, plan, on: ~D[2026-06-23])
        end)

      assert [%{kind: "session", title: "Upper body gym visit"} | _] = ai_tuesday.projected_work
      assert ai_tuesday.input_summary.journal_events == 1
      assert ai_tuesday.headline =~ "track(s)"
      assert Enum.any?(ai_tuesday.sections, &(&1.kind == :sessions))
      assert Enum.any?(ai_tuesday.sections, &(&1.kind == :recovery))

      saturday = Story.project_today!(story, plan, on: ~D[2026-06-27])
      assert projected_titles(saturday, :session) == ["Lower body gym visit"]
      assert "Cycling" in projected_titles(saturday, :track)
      assert "Listen to music or audiobook" in projected_titles(saturday, :track)
      refute "Measure waist" in projected_titles(saturday, :track)
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
        intention: "See daily tracks and gym sessions together",
        from: ~D[2026-06-22],
        until: ~D[2026-07-23]
      )

    Story.add_event_type!(story, plan, "Pages read",
      key: "pages_read",
      payload: %{required: ["pages"]}
    )

    Story.add_track!(story, plan, "Read 20 pages",
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

    Story.add_item_type!(story, plan, "Exercise", key: "exercise")
    Story.add_item!(story, plan, "Chest Press", key: "chest_press", type: "exercise")
    Story.add_item!(story, plan, "Lat Pulldown", key: "lat_pulldown", type: "exercise")

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

  defp translated_old_plan_rough!(story) do
    plan =
      Story.create_plan!(story, "Improve myself!",
        intention: "Improve my fitness and mental health",
        from: ~D[2026-06-16],
        until: ~D[2026-08-06]
      )

    add_translated_event_types!(story, plan)
    add_translated_inventory!(story, plan)
    add_translated_tracks!(story, plan)
    add_translated_session_items!(story, plan)
    add_translated_sessions!(story, plan)

    plan
  end

  defp add_translated_event_types!(story, plan) do
    Story.add_event_type!(story, plan, "Metric logged",
      key: "metric_logged",
      payload: %{required: ["value", "unit"]}
    )

    Story.add_event_type!(story, plan, "Quantity logged",
      key: "quantity_logged",
      payload: %{required: ["amount", "unit"]}
    )

    Story.add_event_type!(story, plan, "Checklist completed",
      key: "checklist_completed",
      payload: %{required: ["completed_items"]}
    )

    Story.add_event_type!(story, plan, "Exercise performed",
      key: "exercise_performed",
      required_links: ["exercise"],
      payload: %{required: ["sets", "reps"]}
    )

    Story.add_event_type!(story, plan, "Cardio performed",
      key: "cardio_performed",
      required_links: ["activity"],
      payload: %{required: ["amount", "unit"]}
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
  end

  defp add_translated_inventory!(story, plan) do
    Story.add_item_type!(story, plan, "Peptide vial",
      key: "peptide_vial",
      display_hints: %{kind: "inventory"}
    )

    Story.add_item!(story, plan, "Retatrutide",
      key: "retatrutide",
      type: "peptide_vial",
      stateful: true,
      facts: %{
        starting_quantity: 20,
        unit: "mg",
        prepared_volume_ml: 20,
        contents: "Retatrutide"
      }
    )
  end

  defp add_translated_tracks!(story, plan) do
    Story.add_track!(story, plan, "Weigh myself",
      key: "weigh_myself",
      event: "metric_logged",
      schedule: Story.every_day(),
      target: %{unit: "kg", quantity_path: "payload.value"}
    )

    Story.add_track!(story, plan, "Measure waist",
      key: "measure_waist",
      event: "metric_logged",
      schedule: Story.every_week(times: 1, on: [:tuesday]),
      target: %{unit: "cm", quantity_path: "payload.value"}
    )

    Story.add_track!(story, plan, "Steps",
      key: "steps",
      event: "quantity_logged",
      schedule: Story.every_day(),
      target: %{
        quantity: 10_000,
        unit: "steps",
        quantity_path: "payload.amount",
        progression: %{from: 1_000, to: 10_000, shape: "linear"}
      }
    )

    Story.add_track!(story, plan, "Cycling",
      key: "cycling",
      event: "cardio_performed",
      schedule: Story.every_week(times: 3, on: [:tuesday, :thursday, :saturday]),
      target: %{
        quantity: 60,
        unit: "min",
        quantity_path: "payload.amount",
        progression: %{from: 20, to: 60, shape: "linear"},
        default_links: %{activity: "cycling"}
      }
    )

    Story.add_track!(story, plan, "Daily habits",
      key: "daily_habits",
      event: "checklist_completed",
      schedule: Story.every_day(),
      target: %{
        checklist_items: [
          %{key: "tidy_bedroom", label: "Tidy Bedroom"},
          %{key: "make_parents_breakfast", label: "Make parents breakfast"},
          %{key: "shower_brush_teeth", label: "Shower / Brush teeth"},
          %{key: "diet_followed", label: "16-8 diet followed"},
          %{key: "commit_code", label: "Commit code"},
          %{key: "avoid_alcohol", label: "Avoid Alcohol"},
          %{key: "avoid_junk_food", label: "Avoid Junk Food"}
        ]
      }
    )

    Story.add_track!(story, plan, "Drink water",
      key: "drink_water",
      event: "quantity_logged",
      schedule: Story.every_day(),
      target: %{quantity: 3, unit: "litres", quantity_path: "payload.amount"}
    )

    Story.add_track!(story, plan, "Retatrutide",
      key: "retatrutide_dose",
      event: "dose_taken",
      schedule: Story.every_week(times: 1, on: [:monday]),
      target: %{
        quantity: 2,
        unit: "mg",
        quantity_path: "payload.amount",
        default_links: %{source_vial: "retatrutide"}
      }
    )

    Story.add_track!(story, plan, "Put bins out",
      key: "put_bins_out",
      event: "checklist_completed",
      schedule: Story.every_week(times: 1, on: [:wednesday]),
      target: %{checklist_items: [%{key: "put_bins_out", label: "Put bins out"}]}
    )

    Story.add_track!(story, plan, "Reading",
      key: "reading",
      event: "quantity_logged",
      schedule: Story.every_day(),
      target: %{quantity: 15, unit: "pages", quantity_path: "payload.amount"}
    )

    Story.add_track!(story, plan, "Watch a film or TV series",
      key: "watch_film_or_tv",
      event: "quantity_logged",
      schedule: Story.every_week(times: 3, on: [:wednesday, :friday, :sunday]),
      target: %{quantity: 90, unit: "min", quantity_path: "payload.amount"}
    )

    Story.add_track!(story, plan, "Listen to music or audiobook",
      key: "listen_music_or_audiobook",
      event: "quantity_logged",
      schedule: Story.every_week(times: 3, on: [:tuesday, :thursday, :saturday]),
      target: %{quantity: 1, unit: "album", quantity_path: "payload.amount"}
    )
  end

  defp add_translated_session_items!(story, plan) do
    Story.add_item_type!(story, plan, "Cardio activity", key: "cardio_activity")
    Story.add_item!(story, plan, "Cycling", key: "cycling", type: "cardio_activity")
    Story.add_item!(story, plan, "Rowing", key: "rowing", type: "cardio_activity")
    Story.add_item!(story, plan, "Elliptical", key: "elliptical", type: "cardio_activity")

    Story.add_item_type!(story, plan, "Exercise", key: "exercise")
    Story.add_item!(story, plan, "Chest Press", key: "chest_press", type: "exercise")
    Story.add_item!(story, plan, "Lat Pulldown", key: "lat_pulldown", type: "exercise")
    Story.add_item!(story, plan, "Shoulder Press", key: "shoulder_press", type: "exercise")
    Story.add_item!(story, plan, "Leg Press", key: "leg_press", type: "exercise")
    Story.add_item!(story, plan, "Leg Curl", key: "leg_curl", type: "exercise")
    Story.add_item!(story, plan, "Leg Extension", key: "leg_extension", type: "exercise")

    Story.add_pool!(story, plan, "Upper cardio warm-up",
      key: "upper_cardio",
      items: ["rowing", "elliptical"]
    )

    Story.add_pool!(story, plan, "Upper body push", key: "upper_push", items: ["chest_press"])
    Story.add_pool!(story, plan, "Upper body pull", key: "upper_pull", items: ["lat_pulldown"])

    Story.add_pool!(story, plan, "Upper body shoulders",
      key: "upper_shoulders",
      items: ["shoulder_press"]
    )

    Story.add_pool!(story, plan, "Lower cardio warm-up",
      key: "lower_cardio",
      items: ["rowing", "elliptical"]
    )

    Story.add_pool!(story, plan, "Lower body press", key: "lower_press", items: ["leg_press"])

    Story.add_pool!(story, plan, "Lower body hamstrings",
      key: "lower_hamstrings",
      items: ["leg_curl"]
    )

    Story.add_pool!(story, plan, "Lower body quads", key: "lower_quads", items: ["leg_extension"])
  end

  defp add_translated_sessions!(story, plan) do
    Story.add_session!(story, plan, "Upper body gym visit",
      key: "upper_body_gym",
      schedule: Story.every_week(times: 2, on: [:tuesday, :thursday]),
      slots: [
        Story.choose(2, from: "upper_cardio", key: "upper_cardio", name: "Warm-up cardio"),
        Story.choose(1, from: "upper_push", key: "upper_push", name: "Push pattern"),
        Story.choose(1, from: "upper_pull", key: "upper_pull", name: "Pull pattern"),
        Story.choose(1, from: "upper_shoulders", key: "upper_shoulders", name: "Shoulder pattern")
      ]
    )

    Story.add_session!(story, plan, "Lower body gym visit",
      key: "lower_body_gym",
      schedule: Story.every_week(times: 1, on: [:saturday]),
      slots: [
        Story.choose(2, from: "lower_cardio", key: "lower_cardio", name: "Warm-up cardio"),
        Story.choose(1, from: "lower_press", key: "lower_press", name: "Press pattern"),
        Story.choose(1,
          from: "lower_hamstrings",
          key: "lower_hamstrings",
          name: "Hamstring pattern"
        ),
        Story.choose(1, from: "lower_quads", key: "lower_quads", name: "Quad pattern")
      ]
    )
  end

  defp projected_titles(projection, kind) do
    projection.projected_work
    |> Enum.filter(&(&1.kind == kind))
    |> Enum.map(& &1.title)
  end

  defp work_status(projection, title) do
    projection.projected_work
    |> Enum.find(&(&1.title == title))
    |> Map.fetch!(:status)
  end
end
