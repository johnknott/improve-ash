defmodule Improve.Bundles.Marathon.AdaptationTest do
  use ExUnit.Case, async: true

  alias Improve.Bundles.Marathon
  alias Improve.Bundles.Marathon.Adaptation
  alias Improve.Bundles.Marathon.RecentLoad
  alias Improve.Planning.EvaluatorGraph

  test "keeps today's tempo and drops missed quality instead of stacking it" do
    assert {:ok, %{marathon_adaptation: adaptation}, []} =
             Adaptation.evaluate(
               input(
                 recent_missed_work: [
                   %{owner_key: "intervals", title: "Intervals", planned_for: ~D[2026-07-07]}
                 ]
               )
             )

    assert [%{owner_key: "tempo_run", action: :keep, reason: reason}] = adaptation.today
    assert reason == "Missed quality work dropped, not stacked onto today."

    assert [%{kind: :shift_session, effect: :derived, requires_approval: false}] =
             adaptation.proposals
  end

  test "turns first day back after fever into rest and derived deload proposals" do
    assert {:ok, %{marathon_adaptation: adaptation}, []} =
             Adaptation.evaluate(
               input(
                 life_events: [
                   %{type: :illness, from: ~D[2026-07-06], to: ~D[2026-07-08], symptoms: :fever}
                 ]
               )
             )

    assert [%{action: :replace, replacement: :rest, reason: reason}] = adaptation.today
    assert reason == "1 day past a fever; full rest per the neck rule."

    assert Enum.map(adaptation.proposals, & &1.kind) == [:deload_week, :shift_session]
    assert Enum.all?(adaptation.proposals, &(&1.effect == :derived))
    assert Enum.all?(adaptation.proposals, &(not &1.requires_approval))
  end

  test "turns an active injury into cross-training and a derived deload proposal" do
    assert {:ok, %{marathon_adaptation: adaptation}, []} =
             Adaptation.evaluate(
               input(
                 date: ~D[2026-07-16],
                 life_events: [
                   %{type: :injury, area: :calf, severity: 2, from: ~D[2026-07-16]}
                 ]
               )
             )

    assert [%{action: :replace, replacement: :cross_train, reason: reason}] = adaptation.today
    assert reason == "Running paused for calf; use cross-training or rest today."

    assert [%{kind: :deload_week, effect: :derived, requires_approval: false}] =
             adaptation.proposals
  end

  test "reduces the first run back after a fully-off holiday when recent load is low" do
    assert {:ok, %{marathon_adaptation: adaptation}, []} =
             Adaptation.evaluate(
               input(
                 date: ~D[2026-08-24],
                 projected_work: [],
                 recent_load_km: %{value: 0, unit: "km"},
                 time_off_windows: [
                   %{
                     key: "summer_holiday",
                     availability: :fully_off,
                     starts_on: ~D[2026-08-10],
                     ends_on: ~D[2026-08-23]
                   }
                 ]
               )
             )

    assert [%{action: :add, replacement: :easy_run, reason: reason}] = adaptation.today
    assert reason == "First run back after time off; keep it easy and short."

    assert [%{kind: :rebuild_week, effect: :derived, requires_approval: false}] =
             adaptation.proposals
  end

  test "runs after the real recent-load evaluator in the concrete graph" do
    host_input =
      input(
        tracks: [%{id: "tempo-track", key: "tempo_run", target: %{"unit" => "km"}}],
        journal_events: [
          %{
            id: "tempo",
            track_id: "tempo-track",
            status: :active,
            effective_at: ~U[2026-07-05 20:00:00Z],
            payload: %{"amount" => 18, "unit" => "km"}
          }
        ]
      )
      |> Map.delete(:recent_load_km)

    evaluators = %{
      recent_load_metric: &RecentLoad.evaluate/1,
      marathon_target_adjustment: &Improve.Bundles.Marathon.TargetAdjustment.evaluate/1,
      marathon_adaptation: &Adaptation.evaluate/1
    }

    assert {:ok, result} =
             EvaluatorGraph.run(
               Marathon.evaluator_descriptors(),
               host_input,
               evaluators
             )

    assert :recent_load_metric in result.order
    assert :marathon_adaptation in result.order
    assert result.outputs.recent_load_km.value == 18

    assert result.outputs.marathon_adaptation.today == [
             %{
               owner_key: "tempo_run",
               title: "Tempo run",
               action: :keep,
               reason: "Keep today's projected work."
             }
           ]
  end

  defp input(overrides) do
    Map.merge(
      %{
        date: ~D[2026-07-09],
        as_of_date: ~D[2026-07-09],
        timezone: "Etc/UTC",
        projected_work: [
          %{
            kind: :track,
            title: "Tempo run",
            payload: %{track_key: "tempo_run"}
          }
        ],
        recent_missed_work: [],
        journal_events: [],
        life_events: [],
        time_off_windows: [],
        plan_skeleton: %{ends_on: ~D[2026-10-04], deadline: %{movable?: false}},
        track_guidance: %{"tempo_run" => %{"pace" => %{"label" => "5:25/km"}}},
        recent_load_km: %{value: 18, unit: "km", window_days: 7}
      },
      Map.new(overrides)
    )
  end
end
