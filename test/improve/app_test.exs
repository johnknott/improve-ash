defmodule Improve.AppTest do
  use Improve.DataCase, async: true

  alias Improve.Accounts
  alias Improve.App
  alias Improve.Bundles.Marathon.PaceDerivation
  alias Improve.Journal
  alias Improve.Plans

  describe "product-facing target and record constructors" do
    test "builds friendly target and record maps" do
      assert App.fixed(20, "pages") == %{type: :fixed, quantity: 20, unit: "pages"}

      assert App.metric("Bodyweight", unit: "kg") == %{
               type: :metric,
               metric: "Bodyweight",
               unit: "kg"
             }

      assert App.checklist(["Tidy room"]) == %{type: :checklist, items: ["Tidy room"]}

      assert App.period_total(100, "pages", per: :week) == %{
               type: :period_total,
               quantity: 100,
               unit: "pages",
               per: :week
             }

      assert App.progression(1_000, 10_000, unit: "steps", shape: :linear) == %{
               type: :progression,
               from: 1_000,
               to: 10_000,
               unit: "steps",
               shape: :linear
             }

      assert App.adaptive(fields: [:sets, :reps, :load], effort: :rpe, review: :weekly) == %{
               type: :adaptive,
               fields: [:sets, :reps, :load],
               effort: :rpe,
               review: :weekly
             }

      assert App.number("pages") == %{
               type: :number,
               field: "amount",
               unit: "pages",
               quantity_path: "payload.amount"
             }

      assert App.fields([:sets, :reps, :load]) == %{
               type: :fields,
               fields: ["sets", "reps", "load"]
             }
    end

    test "builds adaptive session slot suggestion rules" do
      assert App.choose(1,
               from: "practice_items",
               suggest:
                 App.adaptive(
                   fields: [:rounds, :duration_minutes],
                   effort: :effort,
                   review: :weekly
                 ),
               start_with: %{rounds: 2, duration_minutes: 10, effort: "easy"}
             ) == %{
               count: 1,
               from: "practice_items",
               optional: false,
               rules: %{
                 suggestion_target: %{
                   type: :adaptive,
                   fields: [:rounds, :duration_minutes],
                   effort: :effort,
                   review: :weekly
                 },
                 cold_start_payload: %{rounds: 2, duration_minutes: 10, effort: "easy"}
               }
             }
    end

    test "returns an honest projection diagnostic for unknown targets" do
      user = user!("app-target-diagnostic@example.com")

      plan =
        App.create_plan!("Moonshot",
          actor: user,
          intention: "Surface authoring problems",
          from: ~D[2026-06-23],
          until: ~D[2026-07-23]
        )

      App.add_event_type!(plan, "Moonshot logged",
        actor: user,
        key: "moonshot_logged",
        payload: %{required: ["amount"]}
      )

      App.add_track!(plan, "Moonshot",
        actor: user,
        key: "moonshot",
        event: "moonshot_logged",
        schedule: App.every_day(),
        target: %{type: :moonshot, quantity: 1},
        records: App.number("moon")
      )

      projection = App.project_today!(plan, actor: user, date: ~D[2026-06-23])

      assert [
               %{
                 code: :unknown_track_target_type,
                 severity: :warning,
                 details: %{target_type: "moonshot"}
               }
             ] =
               projection.diagnostics
    end
  end

  describe "product-facing schedule constructors" do
    test "builds friendly schedule maps" do
      assert App.every_day() == %{kind: :every_day, rules: %{}}

      assert App.selected_weekdays([:monday, "wednesday"]) == %{
               kind: :selected_weekdays,
               rules: %{"weekdays" => ["monday", "wednesday"]}
             }

      assert App.every_n_days(3) == %{kind: :every_n_days, rules: %{"interval_days" => 3}}

      assert App.times_per_week(3, on: [:monday, :wednesday], minimum_gap_days: 1) == %{
               kind: :times_per_week,
               rules: %{
                 "times" => 3,
                 "allowed_weekdays" => ["monday", "wednesday"],
                 "minimum_gap_days" => 1
               }
             }

      assert App.every_n_weeks(2, on: [:saturday]) == %{
               kind: :every_n_weeks,
               rules: %{"interval_weeks" => 2, "weekdays" => ["saturday"]}
             }

      assert App.monthly(day: 15) == %{kind: :monthly, rules: %{"day" => 15}}
      assert App.after_completion(days: 2) == %{kind: :after_completion, rules: %{"days" => 2}}

      assert App.custom("after a good weather day") == %{
               kind: :custom,
               rules: %{"description" => "after a good weather day"}
             }
    end

    test "projects supported schedule shapes" do
      user = user!("app-schedule-shapes@example.com")

      plan =
        App.create_plan!("Schedules",
          actor: user,
          intention: "Try schedule shapes",
          from: ~D[2026-06-23],
          until: ~D[2026-07-23]
        )

      App.add_event_type!(plan, "Check in",
        actor: user,
        key: "check_in",
        payload: %{required: ["amount"]}
      )

      App.add_track!(plan, "Every three days",
        actor: user,
        key: "every_three_days",
        event: "check_in",
        schedule: App.every_n_days(3),
        target: App.fixed(1, "check"),
        records: App.number("check")
      )

      App.add_track!(plan, "Monthly check",
        actor: user,
        key: "monthly_check",
        event: "check_in",
        schedule: App.monthly(day: 15),
        target: App.fixed(1, "check"),
        records: App.number("check")
      )

      App.add_track!(plan, "Every two weeks",
        actor: user,
        key: "every_two_weeks",
        event: "check_in",
        schedule: App.every_n_weeks(2, on: [:tuesday]),
        target: App.fixed(1, "check"),
        records: App.number("check")
      )

      due = App.project_today!(plan, actor: user, date: ~D[2026-06-26])
      assert "Every three days" in Enum.map(due.projected_work, & &1.title)

      not_due = App.project_today!(plan, actor: user, date: ~D[2026-06-27])
      refute "Every three days" in Enum.map(not_due.projected_work, & &1.title)

      monthly_due = App.project_today!(plan, actor: user, date: ~D[2026-07-15])
      assert "Monthly check" in Enum.map(monthly_due.projected_work, & &1.title)
      assert monthly_due.diagnostics == []

      every_two_weeks_due = App.project_today!(plan, actor: user, date: ~D[2026-07-07])
      assert "Every two weeks" in Enum.map(every_two_weeks_due.projected_work, & &1.title)

      every_two_weeks_off_week = App.project_today!(plan, actor: user, date: ~D[2026-06-30])
      refute "Every two weeks" in Enum.map(every_two_weeks_off_week.projected_work, & &1.title)
    end
  end

  describe "product-facing authoring and track logging" do
    test "authors and logs a track using target metadata" do
      user = user!("app-track@example.com")

      plan =
        App.create_plan!("Reading",
          actor: user,
          intention: "Read every day",
          from: ~D[2026-06-23],
          until: ~D[2026-07-23]
        )

      track =
        App.add_track!(plan, "Read 20 pages",
          actor: user,
          key: "daily_reading",
          schedule: App.every_day(),
          target: App.fixed(20, "pages"),
          records: App.number("pages")
        )

      event_type = Plans.get_event_type!(track.event_type_id, actor: user)

      projection = App.project_today!(plan, actor: user, date: ~D[2026-06-23])

      log =
        App.log_track!(projection,
          actor: user,
          track: "daily_reading",
          payload: %{amount: 25, note: "Read before bed"}
        )

      assert log.event.event_type_id == event_type.id
      assert event_type.key == "daily_reading_logged"
      assert event_type.payload_schema["required"] == ["amount"]
      assert log.event.track_id == track.id
      assert log.event.summary == "25 pages for Read 20 pages"
      assert log.event.quantity == Decimal.new(25)
      assert log.event.unit == "pages"
      assert log.event.note == "Read before bed"
      assert track.target["type"] == "fixed"
      assert track.target["quantity"] == 20
      assert track.target["quantity_path"] == "payload.amount"
      assert track.target["records"]["type"] == "number"

      summary = Plans.summarize_plan!(plan, actor: user)
      assert summary.event_types == 1
      assert summary.tracks == 1
      assert summary.schedules == 1

      assert [%{id: event_id}] = Journal.read_journal!(plan, actor: user)
      assert event_id == log.event.id
    end

    test "uses track default links when logging an effectful track" do
      user = user!("app-track-links@example.com")

      plan =
        App.create_plan!("Inventory",
          actor: user,
          intention: "Track dose history and inventory",
          from: ~D[2026-06-22],
          until: ~D[2026-09-14]
        )

      App.add_item_type!(plan, "Peptide vial", actor: user, key: "peptide_vial")

      App.add_item!(plan, "Retatrutide",
        actor: user,
        key: "retatrutide",
        type: "peptide_vial",
        stateful: true,
        facts: %{starting_quantity: 20, unit: "mg"}
      )

      App.add_event_type!(plan, "Dose taken",
        actor: user,
        key: "dose_taken",
        required_links: ["source_vial"],
        payload: %{required: ["amount", "unit"]},
        effects: [
          App.subtract_quantity(
            from: "source_vial",
            quantity: "payload.amount",
            unit: "payload.unit"
          )
        ]
      )

      App.add_track!(plan, "Retatrutide",
        actor: user,
        key: "retatrutide_dose",
        event: "dose_taken",
        schedule: App.every_week(times: 1, on: [:monday]),
        target: %{
          quantity: 2,
          unit: "mg",
          quantity_path: "payload.amount",
          summary_template: "Took %{quantity} %{unit} Retatrutide",
          default_links: %{source_vial: "retatrutide"}
        }
      )

      projection = App.project_today!(plan, actor: user, date: ~D[2026-06-22])

      log =
        App.log_track!(projection,
          actor: user,
          track: "retatrutide_dose",
          payload: %{amount: 2, unit: "mg", site: "abdomen"}
        )

      assert log.event.summary == "Took 2 mg Retatrutide"
      assert [%{role: "source_vial"}] = log.event_item_links

      assert [%{effect_type: :subtract_quantity, quantity: quantity, unit: "mg"}] =
               log.item_effects

      assert Decimal.equal?(quantity, Decimal.new(2))

      state = App.get_item_state!(plan, "retatrutide", actor: user)
      assert Decimal.equal?(state.calculated_state.current_quantity, Decimal.new(18))
    end

    test "defines a generic stateful item and derives quantity from active effects" do
      user = user!("app-generic-stateful-item@example.com")

      plan =
        App.create_plan!("Supplies",
          actor: user,
          intention: "Track a reusable supply container",
          from: ~D[2026-06-22],
          until: ~D[2026-07-23]
        )

      item_type =
        App.add_item_type!(plan, "Supply container",
          actor: user,
          key: "supply_container",
          facts: [:starting_quantity, :unit, :low_quantity_threshold]
        )

      container =
        App.add_item!(plan, "Workshop bin",
          actor: user,
          key: "workshop_bin",
          type: "supply_container",
          starting_quantity: 20,
          unit: "uses",
          low_at: 5
        )

      App.add_event_type!(plan, "Use recorded",
        actor: user,
        key: "use_recorded",
        required_links: ["container"],
        payload: %{required: ["amount", "unit"]},
        effects: [
          App.subtract_quantity(
            item: "container",
            quantity: "payload.amount",
            unit: "payload.unit"
          )
        ]
      )

      App.add_event_type!(plan, "Refill recorded",
        actor: user,
        key: "refill_recorded",
        required_links: ["container"],
        payload: %{required: ["amount", "unit"]},
        effects: [
          App.add_quantity(item: "container", quantity: "payload.amount", unit: "payload.unit")
        ]
      )

      App.add_event_type!(plan, "Count recorded",
        actor: user,
        key: "count_recorded",
        required_links: ["container"],
        payload: %{required: ["amount", "unit"]},
        effects: [
          App.set_quantity(item: "container", quantity: "payload.amount", unit: "payload.unit")
        ]
      )

      App.log_event!(plan,
        actor: user,
        event: "use_recorded",
        on: ~D[2026-06-22],
        links: %{container: "workshop_bin"},
        payload: %{amount: 7, unit: "uses"}
      )

      App.log_event!(plan,
        actor: user,
        event: "refill_recorded",
        on: ~D[2026-06-23],
        links: %{container: "workshop_bin"},
        payload: %{amount: 4, unit: "uses"}
      )

      App.log_event!(plan,
        actor: user,
        event: "count_recorded",
        on: ~D[2026-06-24],
        links: %{container: "workshop_bin"},
        payload: %{amount: 11, unit: "uses"}
      )

      assert item_type.facts_schema == %{
               "optional" => ["starting_quantity", "unit", "low_quantity_threshold"]
             }

      assert container.stateful == true
      assert container.facts["starting_quantity"] == 20
      assert container.facts["unit"] == "uses"
      assert container.facts["low_quantity_threshold"] == 5

      state = App.get_item_state!(plan, "workshop_bin", actor: user)
      assert Decimal.equal?(state.calculated_state.current_quantity, Decimal.new(11))
      assert state.calculated_state.unit == "uses"

      assert Enum.map(state.active_effects, & &1.effect_type) == [
               :subtract_quantity,
               :add_quantity,
               :set_quantity
             ]
    end

    test "builds offline events from stable app-facing references" do
      user = user!("app-offline-stable-refs@example.com")

      plan =
        App.create_plan!("Offline references",
          actor: user,
          intention: "Build offline commands from app-facing keys",
          from: ~D[2026-06-22],
          until: ~D[2026-07-23]
        )

      App.add_event_type!(plan, "Pages read",
        actor: user,
        key: "pages_read",
        required_links: ["book"],
        payload: %{required: ["pages"]}
      )

      App.add_item_type!(plan, "Book", actor: user, key: "book")
      book = App.add_item!(plan, "Novel", actor: user, key: "novel", type: "book")

      track =
        App.add_track!(plan, "Read 20 pages",
          actor: user,
          key: "daily_reading",
          event: "pages_read",
          schedule: App.every_day(),
          target: App.fixed(20, "pages", quantity_path: "payload.pages")
        )

      offline =
        App.offline_event(plan,
          actor: user,
          event: "pages_read",
          track: "daily_reading",
          on: ~D[2026-06-22],
          summary: "Read 20 pages offline",
          links: %{book: "novel"},
          payload: %{pages: 20},
          operation: "offline-reading-001",
          client_event_id: "offline-reading-001-event",
          idempotency_key: "offline-reading-001-key"
        )

      assert offline.event_type_id
      assert offline.track_id == track.id
      assert [%{role: "book", item_id: item_id}] = offline.item_links
      assert item_id == book.id
      assert offline.idempotency.client_operation_id == "offline-reading-001"
      assert offline.idempotency.client_event_id == "offline-reading-001-event"
      assert offline.idempotency.idempotency_key == "offline-reading-001-key"
    end
  end

  describe "product-facing session logging" do
    test "uses authored session slot defaults for event and payload" do
      user = user!("app-session-defaults@example.com")

      plan =
        App.create_plan!("Gym",
          actor: user,
          intention: "Train consistently",
          from: ~D[2026-06-22],
          until: ~D[2026-07-23]
        )

      event_type =
        App.add_event_type!(plan, "Exercise performed",
          actor: user,
          key: "exercise_performed",
          required_links: ["exercise"],
          payload: %{required: ["sets", "reps"]}
        )

      App.add_item_type!(plan, "Exercise", actor: user, key: "exercise")
      App.add_item!(plan, "Chest Press", actor: user, key: "chest_press", type: "exercise")
      App.add_pool!(plan, "Push exercises", actor: user, key: "push", items: ["chest_press"])

      App.add_session!(plan, "Upper body gym visit",
        actor: user,
        key: "upper_body",
        schedule: App.every_week(times: 1, on: [:monday]),
        defaults: %{
          event: "exercise_performed",
          payload: %{sets: 2, reps: "8", effort: "medium"}
        },
        slots: [
          App.choose(1, from: "push")
        ]
      )

      projection = App.project_today!(plan, actor: user, date: ~D[2026-06-22])
      session = App.start_session!(projection, "upper_body", actor: user)

      started_projection = App.project_today!(plan, actor: user, date: ~D[2026-06-22])

      assert [
               %{
                 kind: :session,
                 status: :started,
                 payload: %{session_state: %{progress_label: "0 of 1 logged"}}
               }
             ] = started_projection.projected_work

      log =
        App.log_session_slot!(session,
          actor: user,
          slot: "push",
          item: "chest_press",
          payload: %{load: 45, load_unit: "kg"},
          note: "Defaulted event and set scheme"
        )

      assert log.event.event_type_id == event_type.id
      assert is_nil(log.event.quantity)
      assert is_nil(log.event.unit)

      assert log.event.payload == %{
               "sets" => 2,
               "reps" => "8",
               "effort" => "medium",
               "load" => 45,
               "load_unit" => "kg"
             }

      assert [%{role: "exercise"}] = log.event_item_links

      completed_projection = App.project_today!(plan, actor: user, date: ~D[2026-06-22])

      assert [
               %{
                 kind: :session,
                 status: :completed,
                 payload: %{session_state: %{progress_label: "1 of 1 logged"}}
               }
             ] = completed_projection.projected_work
    end
  end

  describe "product-facing plan review" do
    test "reviews history deterministically without writing product data" do
      user = user!("app-review@example.com")
      other_user = user!("app-review-other@example.com")

      plan =
        App.create_plan!("Review reading",
          actor: user,
          intention: "Read consistently and review progress",
          from: ~D[2026-06-22],
          until: ~D[2026-07-23]
        )

      App.add_track!(plan, "Read 20 pages",
        actor: user,
        key: "daily_reading",
        schedule: App.every_day(),
        target: App.fixed(20, "pages"),
        records: App.number("pages")
      )

      before_review = Journal.read_journal!(plan, actor: user)

      empty_review = App.review!(plan, actor: user, on: ~D[2026-06-22])

      assert Enum.any?(
               empty_review.suggested_changes,
               &(&1.change == :keep_collecting_history)
             )

      projection = App.project_today!(plan, actor: user, date: ~D[2026-06-22])

      App.log_track!(projection,
        actor: user,
        track: "daily_reading",
        payload: %{amount: 25}
      )

      review = App.review!(plan, actor: user, on: ~D[2026-06-23])

      assert Enum.any?(
               review.observations,
               &(&1.topic == :history and &1.data.active_events == 1)
             )

      assert Enum.any?(
               review.suggested_changes,
               &(&1.change == :tune_recommendations_from_history)
             )

      assert length(Journal.read_journal!(plan, actor: user)) == length(before_review) + 1

      assert_raise Ash.Error.Invalid, fn ->
        App.review!(plan, actor: other_user, on: ~D[2026-06-23])
      end
    end
  end

  describe "approval-required proposal application" do
    test "applies an approved extend_plan proposal through the plan action" do
      user = user!("app-apply-proposal@example.com")

      plan =
        App.create_plan!("Apply proposal",
          actor: user,
          intention: "Approve durable edits deliberately",
          from: ~D[2026-06-22],
          until: ~D[2026-10-04]
        )

      App.add_track!(plan, "Daily check",
        actor: user,
        key: "daily_check",
        schedule: App.every_day(),
        target: App.fixed(1, "check"),
        records: App.number("check")
      )

      before_apply = App.project_today!(plan, actor: user, date: ~D[2026-10-11])
      assert before_apply.projected_work == []

      proposal = %{
        kind: :extend_plan,
        requires_approval: true,
        effect: :committed,
        proposed_edit: %{action: :extend_plan, weeks: 2}
      }

      assert {:ok,
              %{
                action: :extend_plan,
                plan: %{id: plan_id, ends_on: ~D[2026-10-18]} = extended_plan
              }} = App.apply_proposal(plan, proposal, actor: user)

      assert plan_id == plan.id
      assert Plans.get_plan!(plan.id, actor: user).ends_on == ~D[2026-10-18]

      after_apply = App.project_today!(extended_plan, actor: user, date: ~D[2026-10-11])

      assert [%{title: "Daily check", status: :planned}] = after_apply.projected_work
    end

    test "returns clear diagnostics for unsupported proposal actions" do
      user = user!("app-apply-proposal-unsupported@example.com")

      plan =
        App.create_plan!("Apply unsupported proposal",
          actor: user,
          intention: "Keep unsupported edits explicit",
          from: ~D[2026-06-22],
          until: ~D[2026-10-04]
        )

      assert {:error, ["adjust_goal requires a track_id."]} =
               App.apply_proposal(plan, %{proposed_edit: %{action: :adjust_goal}}, actor: user)
    end

    test "does not apply proposals to another user's plan" do
      owner = user!("app-apply-proposal-owner@example.com")
      other_user = user!("app-apply-proposal-other@example.com")

      plan =
        App.create_plan!("Private proposal",
          actor: owner,
          intention: "Keep proposal writes owner scoped",
          from: ~D[2026-06-22],
          until: ~D[2026-10-04]
        )

      assert {:error, %Ash.Error.Invalid{}} =
               App.apply_proposal(
                 plan,
                 %{proposed_edit: %{action: :extend_plan, weeks: 1}},
                 actor: other_user
               )
    end
  end

  describe "customize_plan!/2" do
    test "derives paces from a baseline event, writes track guidance, and records the run" do
      user = user!("app-customize@example.com")

      plan =
        App.create_plan!("Customize",
          actor: user,
          intention: "Customize from baseline",
          from: ~D[2026-06-22],
          until: ~D[2026-10-04]
        )

      App.add_event_type!(plan, "Time trial",
        actor: user,
        key: "time_trial",
        payload: %{required: ["distance_km", "minutes"]}
      )

      App.log_event!(plan,
        actor: user,
        event: "time_trial",
        on: ~D[2026-06-21],
        summary: "5k baseline: 25:00",
        payload: %{distance_km: 5, minutes: 25}
      )

      App.add_event_type!(plan, "Run completed",
        actor: user,
        key: "run_completed",
        payload: %{required: ["amount", "unit"]}
      )

      easy_track =
        App.add_track!(plan, "Easy run",
          actor: user,
          key: "easy_run",
          event: "run_completed",
          schedule: App.every_week(times: 1, on: [:wednesday]),
          target: App.fixed(5, "km"),
          records: App.amount("km")
        )

      Plans.update_track!(
        easy_track,
        %{guidance: %{"surface" => "road", "notes" => "Keep this guidance"}},
        actor: user
      )

      App.add_track!(plan, "Tempo run",
        actor: user,
        key: "tempo_run",
        event: "run_completed",
        schedule: App.every_week(times: 1, on: [:thursday]),
        target: App.fixed(8, "km"),
        records: App.amount("km")
      )

      result =
        App.customize_plan!(plan,
          actor: user,
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

      # Derived paces are returned to the caller.
      assert result.outputs.easy_pace == %{secs_per_km: 375, label: "6:15/km"}
      assert result.outputs.tempo_pace == %{secs_per_km: 325, label: "5:25/km"}

      # Guidance was baked into the tracks as ordinary, auditable plan data.
      [easy, tempo] =
        Plans.list_tracks!(actor: user, query: [filter: [plan_id: plan.id]])
        |> Enum.sort_by(& &1.key)

      assert easy.guidance == %{
               "surface" => "road",
               "notes" => "Keep this guidance",
               "pace" => %{"secs_per_km" => 375, "label" => "6:15/km"}
             }

      assert tempo.guidance == %{"pace" => %{"secs_per_km" => 325, "label" => "5:25/km"}}

      # The customization run is recorded with a self-contained baseline snapshot.
      [run] = Plans.list_customizations!(actor: user, query: [filter: [plan_id: plan.id]])
      assert run.kind == :baseline
      assert run.outputs["easy_pace"]["label"] == "6:15/km"
      assert run.applied_changes["easy_run"]["pace"]["label"] == "6:15/km"
      assert run.baseline["event_type_key"] == "time_trial"
      assert run.baseline["payload"]["minutes"] == 25
    end

    test "re-customizing updates the same auditable run rather than stacking duplicates" do
      user = user!("app-recustomize@example.com")

      plan =
        App.create_plan!("Re-customize",
          actor: user,
          intention: "Re-customize",
          from: ~D[2026-06-22],
          until: ~D[2026-10-04]
        )

      App.add_event_type!(plan, "Time trial",
        actor: user,
        key: "time_trial",
        payload: %{required: ["distance_km", "minutes"]}
      )

      App.log_event!(plan,
        actor: user,
        event: "time_trial",
        on: ~D[2026-06-21],
        summary: "5k baseline: 25:00",
        payload: %{distance_km: 5, minutes: 25}
      )

      App.add_event_type!(plan, "Run completed",
        actor: user,
        key: "run_completed",
        payload: %{required: ["amount", "unit"]}
      )

      App.add_track!(plan, "Easy run",
        actor: user,
        key: "easy_run",
        event: "run_completed",
        schedule: App.every_week(times: 1, on: [:wednesday]),
        target: App.fixed(5, "km"),
        records: App.amount("km")
      )

      App.customize_plan!(plan,
        actor: user,
        deriver: PaceDerivation,
        from_baseline: "time_trial",
        derive: %{easy_pace: {:secs_per_km, :five_k, plus: 75}},
        apply_to: %{"easy_run" => :easy_pace}
      )

      App.customize_plan!(plan,
        actor: user,
        deriver: PaceDerivation,
        from_baseline: "time_trial",
        derive: %{easy_pace: {:secs_per_km, :five_k, plus: 90}},
        apply_to: %{"easy_run" => :easy_pace}
      )

      runs = Plans.list_customizations!(actor: user, query: [filter: [plan_id: plan.id]])
      assert length(runs) == 1

      [track] = Plans.list_tracks!(actor: user, query: [filter: [plan_id: plan.id]])
      assert track.guidance["pace"]["secs_per_km"] == 390
    end

    test "rolls back guidance writes if applying customization fails part way through" do
      user = user!("app-customize-rollback@example.com")

      plan =
        App.create_plan!("Rollback customization",
          actor: user,
          intention: "Customize atomically",
          from: ~D[2026-06-22],
          until: ~D[2026-10-04]
        )

      App.add_event_type!(plan, "Time trial",
        actor: user,
        key: "time_trial",
        payload: %{required: ["distance_km", "minutes"]}
      )

      App.log_event!(plan,
        actor: user,
        event: "time_trial",
        on: ~D[2026-06-21],
        summary: "5k baseline: 25:00",
        payload: %{distance_km: 5, minutes: 25}
      )

      App.add_event_type!(plan, "Run completed",
        actor: user,
        key: "run_completed",
        payload: %{required: ["amount", "unit"]}
      )

      easy_track =
        App.add_track!(plan, "Easy run",
          actor: user,
          key: "easy_run",
          event: "run_completed",
          schedule: App.every_week(times: 1, on: [:wednesday]),
          target: App.fixed(5, "km"),
          records: App.amount("km")
        )

      Plans.update_track!(easy_track, %{guidance: %{"surface" => "trail"}}, actor: user)

      assert_raise ArgumentError, ~r/No track "missing_track" exists in this plan/, fn ->
        App.customize_plan!(plan,
          actor: user,
          deriver: PaceDerivation,
          from_baseline: "time_trial",
          derive: %{
            easy_pace: {:secs_per_km, :five_k, plus: 75},
            tempo_pace: {:secs_per_km, :five_k, plus: 25}
          },
          apply_to: [{"easy_run", :easy_pace}, {"missing_track", :tempo_pace}]
        )
      end

      [track] = Plans.list_tracks!(actor: user, query: [filter: [plan_id: plan.id]])
      assert track.guidance == %{"surface" => "trail"}
      assert [] = Plans.list_customizations!(actor: user, query: [filter: [plan_id: plan.id]])
    end

    test "raises with a plain-English diagnostic when the baseline event is missing" do
      user = user!("app-no-baseline@example.com")

      plan =
        App.create_plan!("No baseline",
          actor: user,
          intention: "No baseline",
          from: ~D[2026-06-22],
          until: ~D[2026-10-04]
        )

      App.add_event_type!(plan, "Time trial",
        actor: user,
        key: "time_trial",
        payload: %{required: ["distance_km", "minutes"]}
      )

      assert_raise ArgumentError, ~r/No active baseline event of type "time_trial"/, fn ->
        App.customize_plan!(plan,
          actor: user,
          deriver: PaceDerivation,
          from_baseline: "time_trial",
          derive: %{easy_pace: {:secs_per_km, :five_k, plus: 75}},
          apply_to: %{}
        )
      end
    end
  end

  defp user!(email) do
    Accounts.create_user!(%{email: email, full_name: "App User"})
  end
end
