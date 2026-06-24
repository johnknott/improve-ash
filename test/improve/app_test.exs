defmodule Improve.AppTest do
  use Improve.DataCase, async: true

  alias Improve.Accounts
  alias Improve.App
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

    test "returns an honest projection diagnostic for recognized targets not supported yet" do
      user = user!("app-target-diagnostic@example.com")

      plan =
        App.create_plan!("Metrics",
          actor: user,
          intention: "Record useful measurements",
          from: ~D[2026-06-23],
          until: ~D[2026-07-23]
        )

      App.add_event_type!(plan, "Weight recorded",
        actor: user,
        key: "weight_recorded",
        payload: %{required: ["amount"]}
      )

      App.add_track!(plan, "Bodyweight",
        actor: user,
        key: "bodyweight",
        event: "weight_recorded",
        schedule: App.every_day(),
        target: App.metric("Bodyweight", unit: "kg"),
        records: App.number("kg")
      )

      projection = App.project_today!(plan, actor: user, date: ~D[2026-06-23])

      assert [
               %{
                 code: :unsupported_track_target_type,
                 severity: :info,
                 details: %{target_type: "metric"}
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

    test "projects supported schedule shapes and diagnoses recognized unsupported ones" do
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

      due = App.project_today!(plan, actor: user, date: ~D[2026-06-26])
      assert "Every three days" in Enum.map(due.projected_work, & &1.title)

      not_due = App.project_today!(plan, actor: user, date: ~D[2026-06-27])
      refute "Every three days" in Enum.map(not_due.projected_work, & &1.title)

      assert Enum.any?(due.diagnostics, &(&1.code == :recognized_unsupported_schedule_kind))
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
      assert log.event.quantity == Decimal.new(2)
      assert log.event.unit == "sets"

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

  defp user!(email) do
    Accounts.create_user!(%{email: email, full_name: "App User"})
  end
end
