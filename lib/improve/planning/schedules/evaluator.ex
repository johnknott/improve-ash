defmodule Improve.Planning.Schedules.Evaluator do
  @moduledoc """
  Internal behaviour for schedule projection evaluators.

  This is not a public extension API. It is the narrow internal contract used
  to keep schedule-specific decision logic out of the main projector.
  """

  alias Improve.Planning.Schedules.Evaluation

  @callback kind() :: atom()
  @callback evaluate(Evaluation.t()) :: {:ok, boolean(), [map()]}
end
