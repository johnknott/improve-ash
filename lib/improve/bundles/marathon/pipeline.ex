defmodule Improve.Bundles.Marathon.Pipeline do
  @moduledoc """
  Runs the concrete marathon evaluator graph.
  """

  alias Improve.Bundles.Marathon
  alias Improve.Bundles.Marathon.Adaptation
  alias Improve.Bundles.Marathon.RecentLoad
  alias Improve.Planning.EvaluatorGraph

  @doc """
  Runs recent-load derivation before marathon adaptation.
  """
  def evaluate(input) when is_map(input) do
    EvaluatorGraph.run(Marathon.evaluator_descriptors(), input, %{
      recent_load_metric: &RecentLoad.evaluate/1,
      marathon_adaptation: &Adaptation.evaluate/1
    })
  end
end
