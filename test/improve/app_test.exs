defmodule Improve.AppTest do
  use Improve.DataCase, async: true

  alias Improve.Accounts
  alias Improve.App
  alias Improve.Journal
  alias Improve.Plans

  describe "log_direct_goal!/2" do
    test "logs a direct goal using the goal event type and target metadata" do
      user =
        Accounts.create_user!(%{
          email: "app-direct-goal@example.com",
          full_name: "App Direct Goal"
        })

      plan =
        Plans.create_plan!(
          %{
            name: "Reading",
            intention: "Read every day",
            starts_on: ~D[2026-06-23],
            ends_on: ~D[2026-07-23],
            status: :active
          },
          actor: user
        )

      event_type =
        Plans.create_event_type!(
          %{
            plan_id: plan.id,
            key: "pages_read",
            name: "Pages read",
            payload_schema: %{"required" => ["pages"]}
          },
          actor: user
        )

      direct_goal =
        Plans.create_direct_goal!(
          %{
            plan_id: plan.id,
            key: "daily_reading",
            name: "Read 20 pages",
            event_type_id: event_type.id,
            target: %{
              "quantity" => 20,
              "unit" => "pages",
              "quantity_path" => "payload.pages",
              "summary_template" => "Read %{quantity} %{unit}"
            }
          },
          actor: user
        )

      Plans.create_schedule!(
        %{
          plan_id: plan.id,
          owner_type: :direct_goal,
          owner_id: direct_goal.id,
          kind: :every_day,
          starts_on: ~D[2026-06-23]
        },
        actor: user
      )

      projection = Plans.project_today!(plan, actor: user, date: ~D[2026-06-23])

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

      assert [%{id: event_id}] = Journal.read_journal!(plan, actor: user)
      assert event_id == log.event.id
    end
  end
end
