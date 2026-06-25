defmodule Improve.Planning.DerivedMetrics.RecentLoadTest do
  use ExUnit.Case, async: true

  alias Improve.Planning.DerivedMetrics.RecentLoad
  alias Improve.Planning.EvaluatorCapabilities
  alias Improve.Planning.EvaluatorGraph

  describe "evaluate/1" do
    test "totals active linked running km in the 7-day window ending on as_of_date" do
      assert {:ok, %{recent_load_km: metric}, []} =
               RecentLoad.evaluate(%{
                 as_of_date: ~D[2026-07-09],
                 tracks: [
                   %{id: "tempo-track", key: "tempo_run", target: %{"unit" => "km"}},
                   %{id: "reading-track", key: "reading", target: %{"unit" => "pages"}}
                 ],
                 journal_events: [
                   run_event("old-long", "tempo-track", ~D[2026-07-02], 8),
                   run_event("tempo", "tempo-track", ~D[2026-07-03], 8),
                   run_event("long", "tempo-track", ~D[2026-07-05], 18),
                   run_event("future", "tempo-track", ~D[2026-07-10], 5),
                   run_event("voided", "tempo-track", ~D[2026-07-05], 99, status: :voided),
                   run_event("reading", "reading-track", ~D[2026-07-05], 50)
                 ]
               })

      assert metric == %{
               metric: :recent_load_km,
               value: 26,
               unit: "km",
               window_days: 7,
               as_of: ~D[2026-07-09],
               window_start: ~D[2026-07-03],
               event_ids: ["tempo", "long"]
             }
    end

    test "returns diagnostics for malformed linked run events" do
      assert {:ok, %{recent_load_km: %{value: 0, event_ids: []}}, diagnostics} =
               RecentLoad.evaluate(%{
                 as_of_date: ~D[2026-07-09],
                 tracks: [%{id: "tempo-track", target: %{"unit" => "km"}}],
                 journal_events: [
                   run_event("bad-amount", "tempo-track", ~D[2026-07-05], "far"),
                   run_event("bad-unit", "tempo-track", ~D[2026-07-06], 5, unit: "miles")
                 ]
               })

      assert Enum.map(diagnostics, & &1.message) == [
               "Ignored run event without a numeric km amount.",
               "Ignored run event without a km unit.",
               "No active running history exists in the 7-day load window."
             ]
    end

    test "can feed the concrete evaluator graph dependency" do
      parent = self()

      descriptors = EvaluatorCapabilities.marathon_descriptors()

      host_input = %{
        as_of_date: ~D[2026-07-09],
        tracks: [%{id: "tempo-track", key: "tempo_run", target: %{"unit" => "km"}}],
        journal_events: [run_event("tempo", "tempo-track", ~D[2026-07-05], 18)],
        date: ~D[2026-07-09],
        projected_work: [%{kind: :track, owner_key: "tempo_run"}],
        recent_missed_work: [],
        life_events: [],
        time_off_windows: [],
        plan_skeleton: %{ends_on: ~D[2026-10-04], deadline: %{movable?: false}},
        track_guidance: %{"tempo_run" => %{"pace" => %{"label" => "5:25/km"}}}
      }

      evaluators = %{
        recent_load_metric: &RecentLoad.evaluate/1,
        marathon_adaptation: fn input ->
          send(parent, {:adaptation_input, input})
          {:ok, %{marathon_adaptation: %{today: input.projected_work, proposals: []}}, []}
        end
      }

      assert {:ok, result} = EvaluatorGraph.run(descriptors, host_input, evaluators)

      assert result.order == [:recent_load_metric, :marathon_adaptation]
      assert result.outputs.recent_load_km.value == 18

      assert_received {:adaptation_input, %{recent_load_km: %{value: 18}}}
    end
  end

  defp run_event(id, track_id, date, amount, opts \\ []) do
    %{
      id: id,
      track_id: track_id,
      status: Keyword.get(opts, :status, :active),
      effective_at: DateTime.new!(date, ~T[20:00:00], "Etc/UTC"),
      payload: %{
        "amount" => amount,
        "unit" => Keyword.get(opts, :unit, "km")
      }
    }
  end
end
