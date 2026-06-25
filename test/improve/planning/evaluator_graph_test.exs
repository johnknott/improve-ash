defmodule Improve.Planning.EvaluatorGraphTest do
  use ExUnit.Case, async: true

  alias Improve.Planning.EvaluatorCapabilities
  alias Improve.Planning.EvaluatorGraph

  describe "order/1" do
    test "orders the recent-load producer before marathon adaptation" do
      descriptors =
        EvaluatorCapabilities.marathon_descriptors()
        |> Enum.reverse()

      assert {:ok, ordered} = EvaluatorGraph.order(descriptors)

      assert Enum.map(ordered, & &1.evaluator) == [
               :recent_load_metric,
               :marathon_adaptation
             ]
    end
  end

  describe "run/3" do
    test "runs one concrete graph and injects cached producer output into the consumer" do
      parent = self()

      host_input = host_input()

      evaluators = %{
        recent_load_metric: fn input ->
          send(parent, {:called, :recent_load_metric, input})

          {:ok,
           %{
             recent_load_km: %{
               metric: :recent_load_km,
               value: 46,
               unit: "km",
               window_days: 7
             }
           }, [%{severity: :info, message: "Recent load computed."}]}
        end,
        marathon_adaptation: fn input ->
          send(parent, {:called, :marathon_adaptation, input})

          {:ok,
           %{
             marathon_adaptation: %{
               today: [%{owner_key: "tempo_run", action: :keep}],
               proposals: []
             }
           }, []}
        end
      }

      assert {:ok, result} =
               EvaluatorGraph.run(
                 Enum.reverse(EvaluatorCapabilities.marathon_descriptors()),
                 host_input,
                 evaluators
               )

      assert result.order == [:recent_load_metric, :marathon_adaptation]

      assert %{recent_load_km: %{value: 46}} = result.outputs
      assert %{marathon_adaptation: %{today: [%{owner_key: "tempo_run"}]}} = result.outputs
      assert [%{message: "Recent load computed."}] = result.diagnostics

      assert_received {:called, :recent_load_metric, producer_input}

      assert producer_input == %{
               as_of_date: ~D[2026-07-09],
               tracks: host_input.tracks,
               journal_events: host_input.journal_events
             }

      assert_received {:called, :marathon_adaptation, consumer_input}

      assert consumer_input.recent_load_km == %{
               metric: :recent_load_km,
               value: 46,
               unit: "km",
               window_days: 7
             }

      assert consumer_input.projected_work == host_input.projected_work
      refute_receive {:called, :recent_load_metric, _again}
    end

    test "returns a diagnostic when host input is missing" do
      host_input = Map.delete(host_input(), :tracks)

      assert {:error,
              %{
                code: :missing_evaluator_input,
                details: %{evaluator: :recent_load_metric, missing: [:tracks]}
              }} =
               EvaluatorGraph.run(
                 EvaluatorCapabilities.marathon_descriptors(),
                 host_input,
                 %{
                   recent_load_metric: fn _input -> flunk("should not run") end,
                   marathon_adaptation: fn _input -> flunk("should not run") end
                 }
               )
    end

    test "returns a diagnostic when an evaluator function is missing" do
      assert {:error,
              %{
                code: :missing_evaluator_function,
                details: %{missing: [:marathon_adaptation]}
              }} =
               EvaluatorGraph.run(
                 EvaluatorCapabilities.marathon_descriptors(),
                 host_input(),
                 %{recent_load_metric: fn _input -> {:ok, %{recent_load_km: %{}}, []} end}
               )
    end

    test "returns a diagnostic when an evaluator omits a declared output" do
      evaluators = %{
        recent_load_metric: fn _input -> {:ok, %{}, []} end,
        marathon_adaptation: fn _input -> {:ok, %{marathon_adaptation: %{}}, []} end
      }

      assert {:error,
              %{
                code: :missing_evaluator_output,
                details: %{evaluator: :recent_load_metric, missing: [:recent_load_km]}
              }} =
               EvaluatorGraph.run(
                 EvaluatorCapabilities.marathon_descriptors(),
                 host_input(),
                 evaluators
               )
    end

    test "returns a diagnostic when an evaluator returns an invalid result shape" do
      evaluators = %{
        recent_load_metric: fn _input -> :not_an_evaluator_result end,
        marathon_adaptation: fn _input -> {:ok, %{marathon_adaptation: %{}}, []} end
      }

      assert {:error,
              %{
                code: :invalid_evaluator_result,
                details: %{evaluator: :recent_load_metric}
              }} =
               EvaluatorGraph.run(
                 EvaluatorCapabilities.marathon_descriptors(),
                 host_input(),
                 evaluators
               )
    end
  end

  defp host_input do
    %{
      as_of_date: ~D[2026-07-09],
      tracks: [%{key: "tempo_run"}, %{key: "long_run"}],
      journal_events: [%{status: :active, payload: %{"amount" => 18, "unit" => "km"}}],
      projected_work: [%{kind: :track, owner_key: "tempo_run"}],
      date: ~D[2026-07-09],
      recent_missed_work: [],
      life_events: [],
      time_off_windows: [],
      plan_skeleton: %{ends_on: ~D[2026-10-04], deadline: %{movable?: false}},
      track_guidance: %{"tempo_run" => %{"pace" => %{"label" => "5:25/km"}}}
    }
  end
end
