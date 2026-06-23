defmodule Improve.App.AiContext do
  @moduledoc """
  Product-facing reads for structured AI context.
  """

  alias Improve.Ai
  alias Improve.App.Lookup

  def get_ai_plan_summary!(plan, opts) do
    Ai.get_plan_summary!(plan.id, actor: Keyword.fetch!(opts, :actor))
  end

  def get_ai_today_context!(plan, opts) do
    Ai.project_today!(plan.id, Keyword.fetch!(opts, :date), actor: Keyword.fetch!(opts, :actor))
  end

  def get_ai_recent_journal!(plan, opts) do
    Ai.get_recent_journal_events!(
      plan.id,
      Keyword.get(opts, :limit, 10),
      actor: Keyword.fetch!(opts, :actor)
    )
  end

  def get_ai_item_state!(plan, item_key, opts) do
    actor = Keyword.fetch!(opts, :actor)
    item = Lookup.item!(plan, item_key, actor)
    Ai.get_item_state!(item.id, actor: actor)
  end
end
