defmodule Improve.Planning.Adaptation.MarathonPipeline do
  @moduledoc """
  Runs the concrete marathon evaluator graph.
  """

  alias Improve.Planning.Adaptation.Marathon
  alias Improve.Planning.DerivedMetrics.RecentLoad
  alias Improve.Planning.EvaluatorCapabilities
  alias Improve.Planning.EvaluatorGraph

  @doc """
  Runs recent-load derivation before marathon adaptation.
  """
  def evaluate(input) when is_map(input) do
    EvaluatorGraph.run(EvaluatorCapabilities.marathon_descriptors(), input, %{
      recent_load_metric: &RecentLoad.evaluate/1,
      marathon_adaptation: &Marathon.evaluate/1
    })
  end
end
