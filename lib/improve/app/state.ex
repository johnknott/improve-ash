defmodule Improve.App.State do
  @moduledoc """
  Product-facing state reads.
  """

  alias Improve.App.Lookup
  alias Improve.Journal

  def get_item_state!(plan, item_key, opts) do
    actor = Keyword.fetch!(opts, :actor)
    item = Lookup.item!(plan, item_key, actor)
    Journal.get_item_state!(item, actor: actor)
  end
end
