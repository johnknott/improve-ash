defmodule Improve.Planning.Targets.Evaluator do
  @moduledoc """
  Internal behaviour for target diagnostic evaluators.

  This is intentionally scoped to projection diagnostics, not a public target
  extension API.
  """

  alias Improve.Planning.Targets.Evaluation

  @type diagnostic :: map()
  @type diagnostics_result :: [diagnostic()]
  @type completion_status :: :completed | :incomplete
  @type completion :: %{
          required(:status) => completion_status(),
          optional(:completed_events) => [map()],
          optional(:progress) => map()
        }
  @type completion_result :: {:ok, completion(), [diagnostic()]}

  @callback target_type() :: String.t()
  @callback diagnostics(Evaluation.t()) :: diagnostics_result()
  @callback completion(Evaluation.t()) :: completion_result()
end
