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
    plan.id
    |> Ai.project_today!(Keyword.fetch!(opts, :date), actor: Keyword.fetch!(opts, :actor))
    |> shape_today_context()
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

  defp shape_today_context(context) do
    projected_work = get(context, :projected_work, [])
    sessions = Enum.filter(projected_work, &(get(&1, :kind) == "session"))
    direct_goals = Enum.filter(projected_work, &(get(&1, :kind) == "direct_goal"))
    completed = Enum.filter(projected_work, &(get(&1, :status) == "completed"))

    still_to_do =
      Enum.filter(projected_work, &(get(&1, :status) in ["planned", "started", "partial"]))

    missed_or_skipped = Enum.filter(projected_work, &(get(&1, :status) in ["missed", "skipped"]))

    context
    |> Map.put(:headline, headline(sessions, direct_goals, completed, still_to_do))
    |> Map.put(:sections, sections(sessions, direct_goals))
    |> Map.put(:completed, completed)
    |> Map.put(:still_to_do, still_to_do)
    |> Map.put(:missed_or_skipped, missed_or_skipped)
  end

  defp headline(sessions, direct_goals, completed, still_to_do) do
    "Today has #{length(direct_goals)} direct goal(s) and #{length(sessions)} session(s). " <>
      "#{length(completed)} completed; #{length(still_to_do)} still to do."
  end

  defp sections(sessions, direct_goals) do
    grouped_direct_goals = Enum.group_by(direct_goals, &direct_goal_section/1)

    [
      section(:sessions, "Sessions", sessions),
      section(:daily_goals, "Daily goals", Map.get(grouped_direct_goals, :daily_goals, [])),
      section(
        :linked_item_goals,
        "Linked item goals",
        Map.get(grouped_direct_goals, :linked_item_goals, [])
      ),
      section(:recovery, "Recovery and mind", Map.get(grouped_direct_goals, :recovery, [])),
      section(:other_goals, "Other goals", Map.get(grouped_direct_goals, :other_goals, []))
    ]
    |> Enum.reject(&(get(&1, :items) == []))
  end

  defp section(kind, title, items) do
    %{
      kind: kind,
      title: title,
      count: length(items),
      items: items
    }
  end

  defp direct_goal_section(work) do
    title = work |> get(:title, "") |> to_string() |> String.downcase()
    target = work |> get(:direct_goal, %{}) |> get(:target, %{}) |> ensure_map()
    unit = target |> get(:unit, "") |> to_string() |> String.downcase()
    default_links = target |> get(:default_links, %{}) |> ensure_map()

    cond do
      map_size(default_links) > 0 ->
        :linked_item_goals

      title =~ "reading" or title =~ "watch" or title =~ "listen" or
          unit in ["pages", "album"] ->
        :recovery

      title =~ "bins" ->
        :other_goals

      true ->
        :daily_goals
    end
  end

  defp get(map, key, default \\ nil)

  defp get(map, key, default) when is_map(map) do
    Map.get(map, key, Map.get(map, to_string(key), default))
  end

  defp get(_value, _key, default), do: default

  defp ensure_map(value) when is_map(value), do: value
  defp ensure_map(_value), do: %{}
end
