defmodule Improve.Bundles.Marathon.CommittedPlanEditsTest do
  use ExUnit.Case, async: true

  alias Improve.Bundles.Marathon.Adaptation
  alias Improve.Bundles.Marathon.CommittedPlanEdits

  test "proposes an approval-required extension after fever illness" do
    assert [
             %{
               kind: :extend_plan,
               requires_approval: true,
               effect: :committed,
               proposed_edit: %{action: :extend_plan, weeks: 1}
             }
           ] =
             CommittedPlanEdits.proposals(
               input(
                 life_events: [
                   %{type: :illness, from: ~D[2026-07-06], to: ~D[2026-07-08], symptoms: :fever}
                 ]
               )
             )
  end

  test "proposes a larger approval-required extension for moderate injury" do
    assert [
             %{
               kind: :extend_plan,
               requires_approval: true,
               effect: :committed,
               proposed_edit: %{action: :extend_plan, weeks: 2}
             }
           ] =
             CommittedPlanEdits.proposals(
               input(
                 date: ~D[2026-07-16],
                 life_events: [
                   %{type: :injury, area: :calf, severity: 2, from: ~D[2026-07-16]}
                 ]
               )
             )
  end

  test "proposes extension for movable deadline after time off" do
    assert [
             %{
               kind: :extend_plan,
               effect: :committed,
               requires_approval: true,
               proposed_edit: %{action: :extend_plan, weeks: 2}
             }
           ] =
             CommittedPlanEdits.proposals(
               input(
                 date: ~D[2026-08-24],
                 plan_skeleton: %{deadline: %{movable?: true}},
                 time_off_windows: [holiday()]
               )
             )
  end

  test "proposes goal adjustment rather than extension for fixed deadline after time off" do
    assert [
             %{
               kind: :adjust_goal,
               effect: :committed,
               requires_approval: true,
               proposed_edit: %{action: :adjust_goal, reason: :fixed_deadline_after_time_off}
             }
           ] =
             CommittedPlanEdits.proposals(
               input(
                 date: ~D[2026-08-24],
                 plan_skeleton: %{deadline: %{movable?: false}},
                 time_off_windows: [holiday()]
               )
             )
  end

  test "marathon evaluator keeps committed proposals separate from derived proposals" do
    assert {:ok, %{marathon_adaptation: adaptation}, []} =
             Adaptation.evaluate(
               input(
                 life_events: [
                   %{type: :illness, from: ~D[2026-07-06], to: ~D[2026-07-08], symptoms: :fever}
                 ]
               )
             )

    assert Enum.map(adaptation.proposals, & &1.effect) == [:derived, :derived]
    assert [%{effect: :committed, requires_approval: true}] = adaptation.committed_proposals
  end

  defp input(overrides) do
    Map.merge(
      %{
        date: ~D[2026-07-09],
        life_events: [],
        time_off_windows: [],
        plan_skeleton: %{deadline: %{movable?: false}},
        projected_work: [%{kind: :track, title: "Tempo run", payload: %{track_key: "tempo_run"}}],
        recent_missed_work: [],
        journal_events: [],
        track_guidance: %{},
        recent_load_km: %{value: 18, unit: "km"}
      },
      Map.new(overrides)
    )
  end

  defp holiday do
    %{
      key: "summer_holiday",
      availability: :fully_off,
      starts_on: ~D[2026-08-10],
      ends_on: ~D[2026-08-23]
    }
  end
end
