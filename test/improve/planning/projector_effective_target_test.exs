defmodule Improve.Planning.ProjectorEffectiveTargetTest do
  use ExUnit.Case, async: true

  alias Improve.Planning.EffectiveTarget
  alias Improve.Planning.Projector

  describe "effective targets in track projection" do
    test "unadjusted track carries effective_target in payload" do
      projection = project_track(weekly_km_track(), [])

      work = hd(projection.projected_work)
      et = work.payload.effective_target

      assert %EffectiveTarget{} = et
      assert et.adjusted? == false
      assert et.authored == weekly_km_track().target
      assert et.effective == weekly_km_track().target
    end

    test "derived adjustment lowers the effective target" do
      track = weekly_km_track()

      adjustments = %{
        track.id => %{
          values: %{"quantity" => 70},
          source: :marathon_adaptation,
          reason: "Deload after illness"
        }
      }

      projection = project_track(track, [], derived_adjustments: adjustments)
      work = hd(projection.projected_work)
      et = work.payload.effective_target

      assert et.adjusted? == true
      assert et.effective["quantity"] == 70
      assert et.authored["quantity"] == 100
      assert et.source == :marathon_adaptation
      assert et.reason == "Deload after illness"
    end

    test "completion evaluates against effective target, not authored" do
      track = weekly_km_track()

      event = event(%{
        id: "e1",
        track_id: track.id,
        quantity: Decimal.new(75),
        effective_at: ~U[2026-06-23 08:00:00Z]
      })

      adjustments = %{
        track.id => %{
          values: %{"quantity" => 70},
          source: :deload,
          reason: "Low load"
        }
      }

      projection = project_track(track, [event], derived_adjustments: adjustments)
      work = hd(projection.projected_work)

      assert work.status == :completed
    end

    test "without adjustment, same quantity is incomplete against authored target" do
      track = weekly_km_track()

      event = event(%{
        id: "e1",
        track_id: track.id,
        quantity: Decimal.new(75),
        effective_at: ~U[2026-06-23 08:00:00Z]
      })

      projection = project_track(track, [event])
      work = hd(projection.projected_work)

      assert work.status == :planned
    end
  end

  defp project_track(track, events, opts \\ []) do
    plan = %{
      id: "plan-1",
      starts_on: ~D[2026-06-01],
      ends_on: ~D[2026-08-01]
    }

    schedule = %{
      id: "schedule-1",
      owner_type: :track,
      owner_id: track.id,
      starts_on: ~D[2026-06-01],
      ends_on: ~D[2026-08-01],
      kind: :every_day,
      recurrence: %{"type" => "daily"}
    }

    input =
      %{
        date: ~D[2026-06-23],
        plan: plan,
        session_templates: [],
        session_slots: [],
        schedules: [schedule],
        time_off_windows: [],
        tracks: [track],
        journal_events: events,
        session_occurrences: [],
        slot_results: [],
        items: [],
        pool_memberships: [],
        environments: [],
        as_of_date: ~D[2026-06-23],
        recent_item_ids: [],
        timezone: "Etc/UTC"
      }
      |> Map.merge(Map.new(opts))

    Projector.project_today(input)
  end

  defp weekly_km_track do
    %{
      id: "track-1",
      plan_id: "plan-1",
      key: "weekly_km",
      name: "Weekly km",
      event_type_id: "et-1",
      target: %{"type" => "period_total", "quantity" => 100, "unit" => "km", "per" => "week"},
      completion_policy: %{},
      missed_policy: %{}
    }
  end

  defp event(attrs) do
    Map.merge(
      %{
        id: "event-1",
        track_id: "track-1",
        status: :active,
        effective_at: ~U[2026-06-23 08:00:00Z],
        quantity: nil,
        unit: nil,
        payload: %{}
      },
      attrs
    )
  end
end
