defmodule Improve.AppTest do
  use Improve.DataCase, async: true

  alias Improve.Accounts
  alias Improve.App
  alias Improve.Journal
  alias Improve.Plans

  describe "product-facing authoring and direct-goal logging" do
    test "authors and logs a direct goal using target metadata" do
      user = user!("app-direct-goal@example.com")

      plan =
        App.create_plan!("Reading",
          actor: user,
          intention: "Read every day",
          from: ~D[2026-06-23],
          until: ~D[2026-07-23]
        )

      event_type =
        App.add_event_type!(plan, "Pages read",
          actor: user,
          key: "pages_read",
          payload: %{required: ["pages"]}
        )

      direct_goal =
        App.add_direct_goal!(plan, "Read 20 pages",
          actor: user,
          key: "daily_reading",
          event: "pages_read",
          schedule: App.every_day(),
          target: %{
            quantity: 20,
            unit: "pages",
            quantity_path: "payload.pages",
            summary_template: "Read %{quantity} %{unit}"
          }
        )

      projection = App.project_today!(plan, actor: user, date: ~D[2026-06-23])

      log =
        App.log_direct_goal!(projection,
          actor: user,
          goal: "daily_reading",
          payload: %{pages: 25, note: "Read before bed"}
        )

      assert log.event.event_type_id == event_type.id
      assert log.event.direct_goal_id == direct_goal.id
      assert log.event.summary == "Read 25 pages"
      assert log.event.quantity == Decimal.new(25)
      assert log.event.unit == "pages"
      assert log.event.note == "Read before bed"

      summary = Plans.summarize_plan!(plan, actor: user)
      assert summary.event_types == 1
      assert summary.direct_goals == 1
      assert summary.schedules == 1

      assert [%{id: event_id}] = Journal.read_journal!(plan, actor: user)
      assert event_id == log.event.id
    end

    test "uses direct-goal default links when logging an effectful goal" do
      user = user!("app-direct-goal-links@example.com")

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

      App.add_direct_goal!(plan, "Retatrutide",
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
        App.log_direct_goal!(projection,
          actor: user,
          goal: "retatrutide_dose",
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

      App.add_exercise!(plan, "Chest Press", actor: user, key: "chest_press")
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
    end
  end

  defp user!(email) do
    Accounts.create_user!(%{email: email, full_name: "App User"})
  end
end
