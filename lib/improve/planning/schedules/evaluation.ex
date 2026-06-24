defmodule Improve.Planning.Schedules.Evaluation do
  @moduledoc """
  Explicit input passed to internal schedule evaluators.

  This stays small on purpose: evaluators decide whether one schedule is due
  for one date from already-assembled projection input.
  """

  @enforce_keys [:schedule, :date, :input]
  defstruct [:schedule, :date, :input]
end
