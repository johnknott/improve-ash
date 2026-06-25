defmodule Improve.App.Customize do
  @moduledoc """
  Product-facing one-time plan customization.

  Customization is Layer 2 of an adaptive plan: it derives values (for example
  training paces) from a baseline event once, bakes them into ordinary plan data
  (track `guidance`), and records a durable customization run so the origin of
  derived static structure is auditable.

  The pure derivation is supplied by a bundle module. This module only
  orchestrates: it resolves the baseline event, derives the outputs, applies them
  to tracks through the normal Ash actions, and persists a customization record.
  """

  alias Improve.App.Lookup
  alias Improve.App.Value
  alias Improve.Journal
  alias Improve.Plans
  alias Improve.Repo

  @notifications_key {__MODULE__, :notifications}

  def customize_plan!(plan, opts) do
    actor = Keyword.fetch!(opts, :actor)
    plan_id = Lookup.plan_id(plan)
    event_type_key = Keyword.fetch!(opts, :from_baseline)
    recipe = Keyword.fetch!(opts, :derive)
    apply_to = Keyword.fetch!(opts, :apply_to)
    key = Keyword.get(opts, :key, "baseline")
    deriver = Keyword.fetch!(opts, :deriver)

    event_type = Lookup.event_type!(plan, event_type_key, actor)
    baseline_event = latest_active_event!(plan_id, event_type, actor)

    case deriver.derive(baseline_event.payload, recipe) do
      {:ok, outputs} ->
        Repo.transaction(fn ->
          reset_notifications!()

          try do
            applied = apply_outputs(plan, outputs, apply_to, actor)

            record =
              persist_customization!(%{
                plan_id: plan_id,
                key: key,
                kind: :baseline,
                actor: actor,
                baseline: baseline_snapshot(baseline_event, event_type),
                recipe: normalize_recipe(recipe),
                outputs: Value.stringify_keys(outputs),
                applied_changes: Value.stringify_keys(applied)
              })

            {%{customization: record, outputs: outputs, applied: applied}, take_notifications!()}
          after
            Process.delete(@notifications_key)
          end
        end)
        |> case do
          {:ok, {result, notifications}} ->
            Ash.Notifier.notify(notifications)
            result

          {:error, error} ->
            raise error
        end

      {:error, diagnostics} ->
        messages = Enum.map_join(diagnostics, "\n", & &1.message)

        raise ArgumentError,
              "Plan customization from baseline #{inspect(event_type_key)} failed:\n#{messages}"
    end
  end

  defp latest_active_event!(plan_id, event_type, actor) do
    Journal.list_events!(
      actor: actor,
      query: [
        filter: [plan_id: plan_id, event_type_id: event_type.id],
        sort: [effective_at: :desc, inserted_at: :desc]
      ]
    )
    |> Enum.find(&(&1.status == :active))
    |> case do
      nil ->
        raise ArgumentError,
              "No active baseline event of type #{inspect(event_type.key)} exists in this plan."

      event ->
        event
    end
  end

  defp apply_outputs(plan, outputs, apply_to, actor) do
    Enum.reduce(apply_to, %{}, fn {track_key, output_name}, acc ->
      track = Lookup.track!(plan, track_key, actor)
      output = Map.fetch!(outputs, output_name)

      guidance =
        (track.guidance || %{})
        |> Value.stringify_keys()
        |> Map.put("pace", Value.stringify_keys(output))

      update_track!(track, %{guidance: guidance}, actor)

      Map.put(acc, track_key, %{
        track_id: track.id,
        pace: output
      })
    end)
  end

  defp persist_customization!(attrs) do
    actor = Map.fetch!(attrs, :actor)
    content = Map.take(attrs, [:key, :kind, :baseline, :recipe, :outputs, :applied_changes])

    case find_customization(attrs.plan_id, attrs.key, actor) do
      nil ->
        create_customization!(Map.put(content, :plan_id, attrs.plan_id), actor)

      existing ->
        update_customization!(existing, content, actor)
    end
  end

  defp update_track!(track, attrs, actor) do
    {record, notifications} =
      Plans.update_track!(track, attrs, actor: actor, return_notifications?: true)

    collect_notifications!(notifications)
    record
  end

  defp create_customization!(attrs, actor) do
    {record, notifications} =
      Plans.create_customization!(attrs, actor: actor, return_notifications?: true)

    collect_notifications!(notifications)
    record
  end

  defp update_customization!(customization, attrs, actor) do
    {record, notifications} =
      Plans.update_customization!(customization, attrs, actor: actor, return_notifications?: true)

    collect_notifications!(notifications)
    record
  end

  defp find_customization(plan_id, key, actor) do
    Plans.list_customizations!(
      actor: actor,
      query: [filter: [plan_id: plan_id, key: key]]
    )
    |> List.first()
  end

  defp baseline_snapshot(event, event_type) do
    %{
      event_instance_id: event.id,
      event_type_key: event_type.key,
      effective_at: event.effective_at,
      payload: Value.stringify_keys(event.payload)
    }
  end

  defp normalize_recipe(recipe) do
    Map.new(recipe, fn {name, {unit, field, offset}} ->
      {to_string(name),
       %{
         "unit" => to_string(unit),
         "baseline" => to_string(field),
         "offset" => normalize_offset(offset)
       }}
    end)
  end

  defp normalize_offset(plus: value), do: %{"plus" => value}
  defp normalize_offset(minus: value), do: %{"minus" => value}
  defp normalize_offset(other), do: Value.stringify_keys(other)

  defp reset_notifications! do
    Process.put(@notifications_key, [])
  end

  defp collect_notifications!(notifications) do
    Process.put(@notifications_key, Process.get(@notifications_key, []) ++ notifications)
  end

  defp take_notifications! do
    notifications = Process.get(@notifications_key, [])
    Process.delete(@notifications_key)
    notifications
  end
end
