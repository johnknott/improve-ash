defmodule Improve.Planning.Targets.PeriodTotalTest do
  use ExUnit.Case, async: true

  alias Improve.Planning.Targets.Evaluation
  alias Improve.Planning.Targets.PeriodTotal

  describe "completion/1" do
    test "completes when summed linked quantities reach the weekly target" do
      track =
        track(%{
          target: %{
            "type" => "period_total",
            "quantity" => 100,
            "unit" => "pages",
            "per" => "week",
            "quantity_path" => "payload.amount"
          }
        })

      monday = event(%{id: "event-1", track_id: track.id, payload: %{"amount" => 40}})

      friday =
        event(%{
          id: "event-2",
          track_id: track.id,
          effective_at: ~U[2026-06-26 20:00:00Z],
          payload: %{"amount" => "60"}
        })

      next_week =
        event(%{
          id: "event-3",
          track_id: track.id,
          effective_at: ~U[2026-06-29 20:00:00Z],
          payload: %{"amount" => 100}
        })

      assert {:ok, completion, []} =
               PeriodTotal.completion(%Evaluation{
                 track: track,
                 date: ~D[2026-06-24],
                 journal_events: [monday, friday, next_week]
               })

      assert completion.status == :completed
      assert completion.completed_events == [monday, friday]
      assert completion.progress.total_quantity == "100"
      assert completion.progress.target_quantity == "100"
      assert completion.progress.period == :week
      assert completion.progress.starts_on == ~D[2026-06-22]
      assert completion.progress.ends_on == ~D[2026-06-28]
      assert completion.progress.label == "100 of 100 pages this week"
    end

    test "reports monthly partial progress" do
      track =
        track(%{
          target: %{
            "type" => "period_total",
            "quantity" => 10,
            "unit" => "sessions",
            "per" => :month
          }
        })

      assert {:ok, completion, []} =
               PeriodTotal.completion(%Evaluation{
                 track: track,
                 date: ~D[2026-06-24],
                 journal_events: [
                   event(%{id: "event-1", track_id: track.id, quantity: 3}),
                   event(%{
                     id: "event-2",
                     track_id: track.id,
                     effective_at: ~U[2026-06-30 20:00:00Z],
                     quantity: 4
                   })
                 ]
               })

      assert completion.status == :incomplete
      assert completion.progress.total_quantity == "7"
      assert completion.progress.target_quantity == "10"
      assert completion.progress.period == :month
      assert completion.progress.label == "7 of 10 sessions this month"
    end
  end

  defp track(attrs) do
    Map.merge(
      %{
        id: "track-1",
        plan_id: "plan-1",
        event_type_id: "event-type-1",
        key: "weekly_pages",
        name: "Weekly pages",
        completion_policy: %{},
        missed_policy: %{}
      },
      attrs
    )
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
