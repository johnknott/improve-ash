defmodule Improve.StoriesTest do
  use Improve.DataCase, async: true

  import ExUnit.CaptureIO

  alias Improve.Bundles.Marathon.PaceDerivation
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
             ] = ai_context.work

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

      Story.add_track!(story, plan, "Evening reset",
        key: "evening_reset",
        schedule: Story.every_day(),
        target: Story.checklist(["Tidy room", "Brush teeth"])
      )

      Story.add_track!(story, plan, "Weekly pages",
        key: "weekly_pages",
        schedule: Story.every_day(),
        target: Story.period_total(100, "pages", per: :week),
        records: Story.number("pages")
      )

      Story.add_track!(story, plan, "Daily steps",
        key: "daily_steps",
        schedule: Story.every_day(),
        target: Story.progression(1_000, 10_000, unit: "steps", shape: :linear),
        records: Story.number("steps")
      )

      Story.add_track!(story, plan, "Practice item",
        key: "practice_item",
        schedule: Story.every_day(),
        target: Story.adaptive(fields: [:sets, :reps, :load], effort: :effort),
        records: Story.fields([:sets, :reps, :load, :effort])
      )

      today = Story.project_today!(story, plan, on: ~D[2026-06-23])

      assert today.projected_work |> Enum.map(& &1.title) |> Enum.sort() == [
               "Bodyweight",
               "Daily steps",
               "Evening reset",
               "Practice item",
               "Reading",
               "Weekly pages"
             ]

      assert today.diagnostics == []

      assert Enum.find(today.projected_work, &(&1.title == "Bodyweight")).payload.target_progress ==
               %{
                 completed_event_count: 0,
                 completed_event_ids: [],
                 recorded_value: nil,
                 unit: "kg",
                 label: "No value recorded"
               }

      assert Enum.find(today.projected_work, &(&1.title == "Evening reset")).payload.target_progress ==
               %{
                 completed_event_count: 0,
                 completed_event_ids: [],
                 completed_count: 0,
                 required_count: 2,
                 completed_items: [],
                 required_items: ["Tidy room", "Brush teeth"],
                 label: "0 of 2 complete"
               }

      Story.log_track!(story, today, track: "reading", payload: %{amount: 25})
      Story.log_track!(story, today, track: "bodyweight", payload: %{amount: 82.5})

      Story.log_track!(story, today,
        track: "evening_reset",
        payload: %{checked_items: ["Tidy room", "Brush teeth"]}
      )

      Story.log_track!(story, today, track: "weekly_pages", payload: %{amount: 100})
      Story.log_track!(story, today, track: "daily_steps", payload: %{amount: 1_000})

      Story.log_track!(story, today,
        track: "practice_item",
        payload: %{sets: 3, reps: 10, load: 40, effort: "steady"}
      )

      completed = Story.project_today!(story, plan, on: ~D[2026-06-23])

      assert completed.projected_work |> Enum.map(& &1.status) |> Enum.uniq() == [:completed]

      assert track_work(completed, "Weekly pages").payload.target_progress.label ==
               "100 of 100 pages this week"

      assert track_work(completed, "Daily steps").payload.target_progress.label ==
               "1000 of 1000 steps expected today"

      assert track_work(completed, "Practice item").payload.target_progress.missing_fields == []
    end

    test "express plan-scoped time off through story helpers" do
      story =
        Story.begin!("test_track_time_off", reset?: true)
        |> Story.user!("Story Time Off", email: "story+test-track-time-off@example.test")

      plan =
        Story.create_plan!(story, "Run consistently",
          intention: "Keep a steady running habit around holidays",
          from: ~D[2026-06-22],
          until: ~D[2026-07-23]
        )

      Story.add_track!(story, plan, "Long run",
        key: "long_run",
        schedule: Story.every_day(),
        target: Story.fixed(20, "km"),
        records: Story.amount("km")
      )

      time_off =
        Story.add_time_off!(story, plan,
          key: "summer_holiday",
          kind: :holiday,
          reason: "Summer holiday",
          from: ~D[2026-06-28],
          to: ~D[2026-07-05],
          availability: :fully_off
        )

      today = Story.project_today!(story, plan, on: ~D[2026-06-28], as_of: ~D[2026-06-29])

      assert [
               %{
                 kind: :track,
                 status: :on_hold,
                 title: "Long run",
                 payload: %{
                   time_off_window: %{id: time_off_id, key: "summer_holiday"}
                 }
               }
             ] = today.projected_work

      assert time_off_id == time_off.id
    end
  end

  describe "customization story helpers" do
    test "derives baseline paces, bakes them into track guidance, and records the run" do
      story =
        Story.begin!("test_customization", reset?: true)
        |> Story.user!("Story Customize", email: "story+test-customization@example.test")

      plan =
        Story.create_plan!(story, "Adaptive running plan",
          intention: "Derive training paces from a baseline",
          from: ~D[2026-06-22],
          until: ~D[2026-10-04]
        )

      Story.add_event_type!(story, plan, "Time trial",
        key: "time_trial",
        payload: %{required: ["distance_km", "minutes"]}
      )

      Story.log_event!(story, plan,
        event: "time_trial",
        on: ~D[2026-06-21],
        summary: "5k baseline: 25:00",
        payload: %{distance_km: 5, minutes: 25}
      )

      Story.add_event_type!(story, plan, "Run completed",
        key: "run_completed",
        payload: %{required: ["amount", "unit"]}
      )

      Story.add_track!(story, plan, "Easy run",
        key: "easy_run",
        event: "run_completed",
        schedule: Story.every_week(times: 1, on: [:wednesday]),
        target: Story.fixed(5, "km"),
        records: Story.amount("km")
      )

      Story.add_track!(story, plan, "Tempo run",
        key: "tempo_run",
        event: "run_completed",
        schedule: Story.every_week(times: 1, on: [:thursday]),
        target: Story.fixed(8, "km"),
        records: Story.amount("km")
      )

      result =
        Story.customize_plan!(story, plan,
          deriver: PaceDerivation,
          from_baseline: "time_trial",
          derive: %{
            easy_pace: {:secs_per_km, :five_k, plus: 75},
            tempo_pace: {:secs_per_km, :five_k, plus: 25}
          },
          apply_to: %{
            "easy_run" => :easy_pace,
            "tempo_run" => :tempo_pace
          }
        )

      assert result.outputs.easy_pace == %{secs_per_km: 375, label: "6:15/km"}
      assert result.outputs.tempo_pace == %{secs_per_km: 325, label: "5:25/km"}

      [easy, tempo] =
        Plans.list_tracks!(actor: story.user, query: [filter: [plan_id: plan.id]])
        |> Enum.sort_by(& &1.key)

      assert easy.guidance["pace"]["label"] == "6:15/km"
      assert tempo.guidance["pace"]["label"] == "5:25/km"

      shown =
        capture_return(fn ->
          Story.show_customization!(story, plan, result)
        end)

      assert shown.kind == :baseline
      assert shown.baseline["event_type_key"] == "time_trial"
    end
  end

  describe "marathon adaptation story helpers" do
    test "run the real evaluator graph from bounded story input" do
      story =
        Story.begin!("test_marathon_adaptation", reset?: true)
        |> Story.user!("Story Marathon", email: "story+test-marathon-adaptation@example.test")

      plan =
        Story.create_plan!(story, "Adaptive running plan",
          intention: "Adapt a running plan around life",
          from: ~D[2026-06-22],
          until: ~D[2026-10-04]
        )

      Story.add_event_type!(story, plan, "Run completed",
        key: "run_completed",
        payload: %{required: ["amount", "unit"]}
      )

      Story.add_track!(story, plan, "Tempo run",
        key: "tempo_run",
        event: "run_completed",
        schedule: Story.every_week(times: 1, on: [:thursday]),
        target: Story.fixed(8, "km"),
        records: Story.amount("km")
      )

      Story.log_event!(story, plan,
        event: "run_completed",
        track: "tempo_run",
        on: ~D[2026-07-05],
        summary: "Tempo run 8 km",
        payload: %{amount: 8, unit: "km"}
      )

      projection = Story.project_today!(story, plan, on: ~D[2026-07-09])

      result =
        Story.marathon_adaptation!(story, plan, projection,
          life_events: [
            %{type: :illness, from: ~D[2026-07-06], to: ~D[2026-07-08], symptoms: :fever}
          ]
        )

      assert :recent_load_metric in result.order
      assert :marathon_target_adjustment in result.order
      assert :marathon_adaptation in result.order
      assert result.outputs.recent_load_km.value == 8
      assert [%{replacement: :rest}] = result.outputs.marathon_adaptation.today

      assert [%{effect: :committed, requires_approval: true}] =
               result.outputs.marathon_adaptation.committed_proposals

      shown =
        capture_return(fn ->
          Story.show_marathon_adaptation!(story, result)
        end)

      assert shown == result
    end
  end

  describe "session-from-pools story helpers" do
    test "express a projected generic session with a completed slot and a swap" do
      story =
        Story.begin!("test_session_from_pools", reset?: true)
        |> Story.user!("Story Session", email: "story+test-session-from-pools@example.test")

      plan =
        Story.create_plan!(story, "Practice starter plan",
          intention: "Build a consistent focused practice habit",
          from: ~D[2026-06-22],
          until: ~D[2026-07-23]
        )

      Story.add_event_type!(story, plan, "Practice logged",
        key: "practice_logged",
        required_links: ["item"],
        payload: %{required: ["rounds", "duration_minutes", "effort"]}
      )

      Story.add_item_type!(story, plan, "Practice item", key: "practice_item")
      Story.add_item!(story, plan, "Piano scales", key: "piano_scales", type: "practice_item")
      Story.add_item!(story, plan, "Sight reading", key: "sight_reading", type: "practice_item")
      Story.add_item!(story, plan, "Ear training", key: "ear_training", type: "practice_item")
      Story.add_item!(story, plan, "Rhythm drills", key: "rhythm_drills", type: "practice_item")
      Story.add_item!(story, plan, "Improvisation", key: "improvisation", type: "practice_item")

      Story.add_pool!(story, plan, "Technique choices",
        key: "technique",
        items: ["piano_scales", "sight_reading"]
      )

      Story.add_pool!(story, plan, "Listening choices",
        key: "listening",
        items: ["ear_training", "rhythm_drills"]
      )

      suggestion =
        Story.adaptive(fields: [:rounds, :duration_minutes], effort: :effort, review: :weekly)

      Story.add_session!(story, plan, "Focused practice",
        key: "focused_practice",
        schedule: Story.every_week(times: 2, on: [:monday, :thursday]),
        slots: [
          Story.choose(2,
            from: "technique",
            suggest: suggestion,
            start_with: %{rounds: 2, duration_minutes: 10, effort: "easy"}
          ),
          Story.choose(2,
            from: "listening",
            suggest: suggestion,
            start_with: %{rounds: 2, duration_minutes: 8, effort: "easy"}
          )
        ]
      )

      today = Story.project_today!(story, plan, on: ~D[2026-06-22])

      assert [
               %{
                 kind: :session,
                 title: "Focused practice",
                 payload: %{session_occurrence: projected_session}
               }
             ] = today.projected_work

      assert [
               %{slot_key: "technique", recommended_items: technique_items},
               %{slot_key: "listening", recommended_items: listening_items}
             ] = projected_session.recommendations

      assert Enum.map(technique_items, & &1.item_key) == ["piano_scales", "sight_reading"]
      assert Enum.map(listening_items, & &1.item_key) == ["ear_training", "rhythm_drills"]
      assert Enum.all?(technique_items ++ listening_items, &(&1.source == "cold_start"))

      session = Story.start_session!(story, today, "focused_practice")
      assert %{session_occurrence: occurrence, slot_results: slot_results} = session
      assert occurrence.status == :started
      assert length(slot_results) == 4

      first_log =
        Story.log_slot!(story, session,
          slot: "technique",
          item: "piano_scales",
          event: "practice_logged",
          payload: %{rounds: 2, duration_minutes: 12, effort: "steady"},
          note: "Felt focused"
        )

      swap_log =
        Story.log_slot!(story, session,
          slot: "technique",
          recommended: "sight_reading",
          actual: "improvisation",
          event: "practice_logged",
          payload: %{rounds: 3, duration_minutes: 10, effort: "playful"},
          note: "Swapped to keep momentum"
        )

      assert first_log.event.summary == "Piano scales performed"
      assert first_log.slot_result.status == :completed

      assert first_log.slot_result.actual_payload == %{
               "duration_minutes" => 12,
               "effort" => "steady",
               "rounds" => 2
             }

      assert first_log.slot_result.notes == "Felt focused"
      assert swap_log.event.summary == "Improvisation performed instead of Sight reading"
      assert swap_log.slot_result.status == :swapped
      assert swap_log.slot_result.recommended_item_id != swap_log.slot_result.actual_item_id

      assert swap_log.slot_result.actual_payload == %{
               "duration_minutes" => 10,
               "effort" => "playful",
               "rounds" => 3
             }

      skip_result =
        Story.skip_slot!(story, session,
          slot: "listening",
          recommended: "ear_training",
          payload: %{reason: "out_of_time"},
          note: "Ran out of time"
        )

      assert skip_result.status == :skipped
      assert skip_result.actual_payload == %{"reason" => "out_of_time"}
      assert skip_result.notes == "Ran out of time"

      slot_statuses =
        Sessions.list_slot_results!(
          actor: story.user,
          query: [filter: [session_occurrence_id: occurrence.id]]
        )
        |> Enum.map(& &1.status)
        |> Enum.frequencies()

      assert slot_statuses.completed == 1
      assert slot_statuses.swapped == 1
      assert slot_statuses.skipped == 1
      assert slot_statuses.planned == 1

      journal_by_summary =
        plan
        |> Journal.read_journal!(actor: story.user)
        |> Map.new(&{&1.summary, &1})

      assert %{
               "Piano scales performed" => first_event,
               "Improvisation performed instead of Sight reading" => swap_event
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
                 session: %{name: "Focused practice"},
                 session_state: %{progress_label: "3 of 4 logged"}
               }
             ] = ai_context.work
    end
  end

  describe "stateful item story helpers" do
    test "log a linked use event and derive item state from generated effects" do
      story =
        Story.begin!("test_stateful_item_effects", reset?: true)
        |> Story.user!("Story Stateful", email: "story+test-stateful-item-effects@example.test")

      plan =
        Story.create_plan!(story, "Supply state plan",
          intention: "Track starting facts, item effects, and derived state",
          from: ~D[2026-06-22],
          until: ~D[2026-09-14]
        )

      Story.add_item_type!(story, plan, "Supply container",
        key: "supply_container",
        facts: [:starting_quantity, :unit, :low_quantity_threshold]
      )

      Story.add_item!(story, plan, "Workshop bin",
        key: "workshop_bin",
        type: "supply_container",
        starting_quantity: 20,
        unit: "uses",
        low_at: 5
      )

      Story.add_event_type!(story, plan, "Use recorded",
        key: "use_recorded",
        required_links: ["container"],
        payload: %{required: ["amount", "unit"]},
        effects: [
          Story.subtract_quantity(
            item: "container",
            quantity: "payload.amount",
            unit: "payload.unit"
          )
        ]
      )

      before_state =
        capture_return(fn ->
          Story.show_item_state!(story, plan, "workshop_bin")
        end)

      assert Decimal.equal?(before_state.calculated_state.current_quantity, Decimal.new(20))
      assert before_state.calculated_state.unit == "uses"
      assert before_state.active_effects == []

      log =
        Story.log_event!(story, plan,
          event: "use_recorded",
          on: ~D[2026-06-22],
          summary: "Use recorded from Workshop bin",
          links: %{container: "workshop_bin"},
          payload: %{amount: 17, unit: "uses", note: "Large project day"}
        )

      assert log.event.summary == "Use recorded from Workshop bin"
      assert log.event.quantity == Decimal.new(17)
      assert log.event.unit == "uses"

      assert [%{role: "container"} = link] = log.event_item_links
      assert [effect] = log.item_effects
      assert effect.item_id == link.item_id
      assert effect.effect_type == :subtract_quantity
      assert effect.quantity == Decimal.new(17)
      assert effect.unit == "uses"

      after_state =
        capture_return(fn ->
          Story.show_item_state!(story, plan, "workshop_bin")
        end)

      assert Decimal.equal?(after_state.calculated_state.current_quantity, Decimal.new(3))
      assert after_state.calculated_state.unit == "uses"
      assert Enum.map(after_state.active_effects, & &1.id) == [effect.id]
      assert [%{code: :low_quantity, message: message}] = after_state.warnings
      assert message == "Item quantity is below the configured low quantity threshold."

      assert [%{id: event_id}] = Journal.read_journal!(plan, actor: story.user)
      assert event_id == log.event.id

      ai_state =
        capture_return(fn ->
          Story.show_ai_item_state!(story, plan, "workshop_bin")
        end)

      assert ai_state.calculated_state.current_quantity == "3"

      assert [%{effect_type: :subtract_quantity, quantity: "17"}] =
               ai_state.active_item_effects
    end
  end

  describe "correction story helpers" do
    test "corrects a logged inventory event while preserving auditable history" do
      story =
        Story.begin!("test_correct_logged_event", reset?: true)
        |> Story.user!("Story Correct", email: "story+test-correct-logged-event@example.test")

      plan = stateful_container_plan!(story, "Correction history plan")

      original =
        Story.log_event!(story, plan,
          event: "use_recorded",
          on: ~D[2026-06-22],
          summary: "Use recorded from Workshop bin",
          links: %{container: "workshop_bin"},
          payload: %{amount: 17, unit: "uses"}
        )

      before_state =
        capture_return(fn ->
          Story.show_item_state!(story, plan, "workshop_bin")
        end)

      assert Decimal.equal?(before_state.calculated_state.current_quantity, Decimal.new(3))

      correction =
        Story.correct_event!(story, original,
          corrected_at: ~U[2026-06-22 21:00:00Z],
          reason: "Amount was entered incorrectly",
          replacement: [
            event: "use_recorded",
            effective_at: ~U[2026-06-22 20:00:00Z],
            summary: "Corrected use from Workshop bin",
            links: %{container: "workshop_bin"},
            payload: %{amount: 12, unit: "uses"}
          ]
        )

      shown_correction =
        capture_return(fn ->
          Story.show_correction_result!(story, correction)
        end)

      assert shown_correction.replacement.event.summary == "Corrected use from Workshop bin"
      assert correction.corrected_event.status == :corrected
      assert [voided_effect] = correction.voided_effects
      assert voided_effect.status == :voided
      assert [replacement_effect] = correction.replacement.item_effects
      assert replacement_effect.status == :active
      assert correction.replacement.event.replaces_event_instance_id == original.event.id

      after_state =
        capture_return(fn ->
          Story.show_item_state!(story, plan, "workshop_bin")
        end)

      assert Decimal.equal?(after_state.calculated_state.current_quantity, Decimal.new(8))
      assert Enum.map(after_state.active_effects, & &1.id) == [replacement_effect.id]

      assert %{corrected: 1, active: 1} =
               plan
               |> Journal.read_journal!(actor: story.user)
               |> Enum.map(& &1.status)
               |> Enum.frequencies()

      ai_state =
        capture_return(fn ->
          Story.show_ai_item_state!(story, plan, "workshop_bin")
        end)

      assert ai_state.calculated_state.current_quantity == "8"

      assert [%{effect_type: :subtract_quantity, quantity: "12"}] =
               ai_state.active_item_effects
    end
  end

  describe "offline story helpers" do
    test "deduplicates offline retries and flags stale slot-linked events" do
      story =
        Story.begin!("test_offline_duplicate_and_stale", reset?: true)
        |> Story.user!("Story Offline", email: "story+test-offline@example.test")

      plan = offline_resilience_plan!(story, "Offline resilience plan")
      today = Story.project_today!(story, plan, on: ~D[2026-06-22])
      session = Story.start_session!(story, today, "focused_practice")

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
          slot: "technique",
          item: "piano_scales",
          event: "practice_logged",
          payload: %{rounds: 2, duration_minutes: 12}
        )
        |> Map.fetch!(:slot_result)

      stale_slot =
        Story.offline_event(story, plan,
          event: "practice_logged",
          on: ~D[2026-06-22],
          summary: "Offline practice retry",
          links: %{item: "piano_scales"},
          payload: %{rounds: 2, duration_minutes: 12},
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
      assert capture_return(fn -> Story.show_offline_results!(story, result) end) == result

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
             ] = ai_context.work

      assert ai_context.input_summary.journal_events == 2
      assert ai_context.input_summary.session_occurrences == 1
      assert ai_context.headline =~ "1 track(s) and 1 session(s)"
      assert Enum.map(ai_context.sections, & &1.kind) == [:sessions, :recovery]
    end
  end

  describe "review story helpers" do
    test "shows deterministic observations and suggested changes" do
      story =
        Story.begin!("test_review_and_adjustment", reset?: true)
        |> Story.user!("Story Review", email: "story+test-review-and-adjustment@example.test")

      plan = hybrid_today_plan!(story, "Review helper plan")
      before = Story.project_today!(story, plan, on: ~D[2026-06-22])

      Story.log_track!(story, before,
        track: "daily_reading",
        payload: %{pages: 25, note: "Read before breakfast"}
      )

      review =
        capture_return(fn ->
          Story.show_review!(story, plan, on: ~D[2026-06-23])
        end)

      assert Enum.any?(review.observations, &(&1.topic == :plan_shape))
      assert Enum.any?(review.observations, &(&1.topic == :history))

      assert Enum.any?(
               review.suggested_changes,
               &(&1.change == :tune_recommendations_from_history)
             )

      assert "Review is deterministic and read-only." in review.reasons
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

      assert [%{kind: "session", title: "Upper body gym visit"} | _] = ai_tuesday.work
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

  defp stateful_container_plan!(story, name) do
    plan =
      Story.create_plan!(story, name,
        intention: "Correct stateful item history",
        from: ~D[2026-06-22],
        until: ~D[2026-09-14]
      )

    Story.add_item_type!(story, plan, "Supply container",
      key: "supply_container",
      facts: [:starting_quantity, :unit]
    )

    Story.add_item!(story, plan, "Workshop bin",
      key: "workshop_bin",
      type: "supply_container",
      starting_quantity: 20,
      unit: "uses"
    )

    Story.add_event_type!(story, plan, "Use recorded",
      key: "use_recorded",
      required_links: ["container"],
      payload: %{required: ["amount", "unit"]},
      effects: [
        Story.subtract_quantity(
          item: "container",
          quantity: "payload.amount",
          unit: "payload.unit"
        )
      ]
    )

    plan
  end

  defp offline_resilience_plan!(story, name) do
    plan =
      Story.create_plan!(story, name,
        intention: "Accept offline logs safely without duplicating or overwriting stale work",
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

    Story.add_event_type!(story, plan, "Practice logged",
      key: "practice_logged",
      required_links: ["item"],
      payload: %{required: ["rounds", "duration_minutes"]}
    )

    Story.add_item_type!(story, plan, "Practice item", key: "practice_item")
    Story.add_item!(story, plan, "Piano scales", key: "piano_scales", type: "practice_item")
    Story.add_item!(story, plan, "Ear training", key: "ear_training", type: "practice_item")

    Story.add_pool!(story, plan, "Technique choices",
      key: "technique",
      items: ["piano_scales"]
    )

    Story.add_pool!(story, plan, "Listening choices",
      key: "listening",
      items: ["ear_training"]
    )

    Story.add_session!(story, plan, "Focused practice",
      key: "focused_practice",
      schedule: Story.every_week(times: 1, on: [:monday]),
      slots: [
        Story.choose(1, from: "technique"),
        Story.choose(1, from: "listening")
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

  defp track_work(projection, title) do
    Enum.find(projection.projected_work, &(&1.title == title))
  end
end
