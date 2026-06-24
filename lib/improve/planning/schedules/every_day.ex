defmodule Improve.Planning.Schedules.EveryDay do
  @moduledoc false

  @behaviour Improve.Planning.Schedules.Evaluator

  def kind, do: :every_day

  def evaluate(_evaluation), do: {:ok, true, []}
end
