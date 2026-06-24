defmodule Improve.Planning.Targets.Fixed do
  @moduledoc false

  @behaviour Improve.Planning.Targets.Evaluator

  def target_type, do: "fixed"

  def diagnostics(_evaluation), do: []
end
