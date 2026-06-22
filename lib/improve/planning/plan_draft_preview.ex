defmodule Improve.Planning.PlanDraftPreview do
  @moduledoc """
  Headless preview for portable plan drafts.
  """

  alias Improve.Planning.Diagnostics
  alias Improve.Planning.PlanDraft

  def preview(draft) do
    draft = PlanDraft.normalize(draft)
    diagnostics = Diagnostics.validate_plan_draft(draft)

    %{
      valid?: diagnostics == [],
      diagnostics: diagnostics,
      plan: plan_summary(draft),
      date_range: %{
        starts_on: value(draft, :starts_on),
        ends_on: value(draft, :ends_on)
      },
      counts: counts(draft),
      lists: lists(draft)
    }
  end

  defp plan_summary(draft) do
    %{
      key: value(draft, :key),
      name: value(draft, :name),
      intention: value(draft, :intention),
      status: value(draft, :status),
      source: value(draft, :source)
    }
  end

  defp counts(draft) do
    %{
      item_types: length(list(draft, :item_types)),
      items: length(list(draft, :items)),
      pools: length(list(draft, :pools)),
      environments: length(list(draft, :environments)),
      event_types: length(list(draft, :event_types)),
      session_templates: length(list(draft, :session_templates)),
      session_slots: session_slot_count(draft),
      direct_goals: length(list(draft, :direct_goals)),
      schedules: length(list(draft, :schedules)),
      sample_events: length(list(draft, :sample_events))
    }
  end

  defp lists(draft) do
    %{
      sessions:
        draft
        |> list(:session_templates)
        |> Enum.map(fn template ->
          %{
            key: value(template, :key),
            name: value(template, :name),
            slots:
              template
              |> list(:slots)
              |> Enum.map(
                &%{key: value(&1, :key), name: value(&1, :name), pool_key: value(&1, :pool_key)}
              )
          }
        end),
      goals:
        draft
        |> list(:direct_goals)
        |> Enum.map(fn goal ->
          %{
            key: value(goal, :key),
            name: value(goal, :name),
            event_type_key: value(goal, :event_type_key),
            target: value(goal, :target) || %{}
          }
        end),
      items:
        draft
        |> list(:items)
        |> Enum.map(
          &%{
            key: value(&1, :key),
            name: value(&1, :name),
            item_type_key: value(&1, :item_type_key)
          }
        ),
      event_types:
        draft
        |> list(:event_types)
        |> Enum.map(&%{key: value(&1, :key), name: value(&1, :name)})
    }
  end

  defp session_slot_count(draft) do
    draft
    |> list(:session_templates)
    |> Enum.map(fn template -> length(list(template, :slots)) end)
    |> Enum.sum()
  end

  defp list(source, key) do
    source
    |> value(key)
    |> case do
      nil -> []
      list when is_list(list) -> list
      map when is_map(map) -> Map.values(map)
      _other -> []
    end
  end

  defp value(source, key) when is_map(source) and is_atom(key) do
    Map.get(source, key) || Map.get(source, Atom.to_string(key))
  end

  defp value(source, key) when is_map(source) and is_binary(key) do
    Map.get(source, key) || Map.get(source, existing_atom(key))
  end

  defp value(_source, _key), do: nil

  defp existing_atom(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end
end
