defmodule Improve.Planning.EvaluatorCapabilitiesTest do
  use ExUnit.Case, async: true

  alias Improve.Planning.EvaluatorCapabilities

  describe "marathon_descriptors/0" do
    test "declares the concrete recent-load producer and adaptation consumer" do
      descriptors = EvaluatorCapabilities.marathon_descriptors()

      assert Enum.map(descriptors, & &1.evaluator) == [
               :recent_load_metric,
               :marathon_adaptation
             ]

      assert Enum.map(descriptors, & &1.kind) == [:derived_metric, :adaptation]
    end

    test "bounds the recent-load producer input to projection history and date" do
      producer = descriptor(:recent_load_metric)

      assert producer.provides == [:recent_load_km]

      assert Enum.sort(producer.requires) ==
               Enum.sort([:as_of_date, :tracks, :journal_events])
    end

    test "bounds the marathon adaptation input around projected work and metrics" do
      consumer = descriptor(:marathon_adaptation)

      assert consumer.provides == [:marathon_adaptation]

      assert Enum.sort(consumer.requires) ==
               Enum.sort([
                 :date,
                 :projected_work,
                 :recent_missed_work,
                 :journal_events,
                 :life_events,
                 :time_off_windows,
                 :plan_skeleton,
                 :track_guidance,
                 :recent_load_km
               ])

      refute :repo in consumer.requires
      refute :database in consumer.requires
      refute :clock in consumer.requires
      refute :whole_projection_input in consumer.requires
    end
  end

  describe "providers_by_capability/1" do
    test "indexes producer descriptors by named output capability" do
      providers =
        EvaluatorCapabilities.marathon_descriptors()
        |> EvaluatorCapabilities.providers_by_capability()

      assert %{recent_load_km: [%{evaluator: :recent_load_metric}]} = providers
      assert %{marathon_adaptation: [%{evaluator: :marathon_adaptation}]} = providers
    end
  end

  describe "dependency_edges/1" do
    test "exposes the concrete dependency without running or ordering evaluators" do
      assert [
               %{
                 provider: :recent_load_metric,
                 consumer: :marathon_adaptation,
                 capability: :recent_load_km
               }
             ] =
               EvaluatorCapabilities.marathon_descriptors()
               |> EvaluatorCapabilities.dependency_edges()
    end
  end

  defp descriptor(evaluator) do
    EvaluatorCapabilities.marathon_descriptors()
    |> Enum.find(&(&1.evaluator == evaluator))
  end
end
