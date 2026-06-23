defmodule Improve.Stories.Story do
  @moduledoc """
  Runtime context for executable product story scripts.

  A story carries stable reset identity and the actor used by product-facing
  helper calls. It is intentionally small: product records still live in the
  normal Ash domains.
  """

  defstruct [:key, :source_key, :user, reset?: true]
end
