defmodule Improve.Planning.Targets.Evaluation do
  @moduledoc """
  Explicit input passed to internal target diagnostic evaluators.

  Target evaluators currently only report projection diagnostics. They do not
  decide completion yet.
  """

  @enforce_keys [:track]
  defstruct [:track]

  @type t :: %__MODULE__{
          track: map()
        }
end
