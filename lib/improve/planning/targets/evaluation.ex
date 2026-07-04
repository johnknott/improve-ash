defmodule Improve.Planning.Targets.Evaluation do
  @moduledoc """
  Explicit input passed to internal target evaluators.

  This stays small on purpose: evaluators decide target-specific completion
  from already-assembled projection input.
  """

  @enforce_keys [:track]
  defstruct [:track, :plan, :date, :as_of_date, journal_events: [], timezone: "Etc/UTC"]

  @type t :: %__MODULE__{
          track: map(),
          plan: map() | nil,
          date: Date.t() | nil,
          as_of_date: Date.t() | nil,
          journal_events: [map()],
          timezone: String.t()
        }
end
