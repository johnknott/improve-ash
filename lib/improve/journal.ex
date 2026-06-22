defmodule Improve.Journal do
  use Ash.Domain,
    extensions: [AshTypescript.Rpc],
    otp_app: :improve

  alias Improve.Journal.LogEventCommand
  alias Improve.Planning.EffectRuleInterpreter
  alias Improve.Plans
  alias Improve.Repo
  alias Improve.Sessions

  typescript_rpc do
    resource Improve.Journal.EventInstance do
      rpc_action(:list_events, :read)
      rpc_action(:get_event, :read, get_by: [:id])
    end

    resource Improve.Journal.ItemEffect do
      rpc_action(:list_item_effects, :read)
    end
  end

  resources do
    resource Improve.Journal.EventInstance do
      define :log_event, action: :log
      define :get_event, action: :read, get_by: [:id]
      define :list_events, action: :read
      define :void_event, action: :void
      define :mark_event_corrected, action: :mark_corrected
    end

    resource Improve.Journal.EventItemLink do
      define :create_event_item_link, action: :create
      define :list_event_item_links, action: :read
    end

    resource Improve.Journal.ItemEffect do
      define :create_item_effect, action: :create
      define :list_item_effects, action: :read
      define :void_item_effect, action: :void
    end
  end

  @notifications_key {__MODULE__, :notifications}

  def log_generic_event(attrs, opts) do
    actor = Keyword.fetch!(opts, :actor)

    with {:ok, command} <- LogEventCommand.from_attrs(attrs) do
      Repo.transaction(fn ->
        reset_notifications!()

        {persist_log_event_command!(command, actor), take_notifications!()}
      end)
      |> case do
        {:ok, {result, notifications}} ->
          Ash.Notifier.notify(notifications)
          {:ok, result}

        {:error, error} ->
          {:error, error}
      end
    end
  end

  def log_generic_event!(attrs, opts) do
    case log_generic_event(attrs, opts) do
      {:ok, result} -> result
      {:error, error} when is_list(error) -> raise ArgumentError, Enum.join(error, " ")
      {:error, error} -> raise inspect(error)
    end
  end

  def log_session_item_event!(attrs, opts) do
    actor = Keyword.fetch!(opts, :actor)
    slot_result = Map.fetch!(attrs, :slot_result)
    item = Map.fetch!(attrs, :item)
    event_type = Map.fetch!(attrs, :event_type)
    session_occurrence = Map.fetch!(attrs, :session_occurrence)
    role = Map.fetch!(attrs, :role)

    Repo.transaction(fn ->
      reset_notifications!()

      event =
        create!(
          __MODULE__,
          :log_event!,
          actor,
          %{
            plan_id: session_occurrence.plan_id,
            event_type_id: event_type.id,
            session_occurrence_id: session_occurrence.id,
            slot_result_id: slot_result.id,
            effective_at: Map.fetch!(attrs, :effective_at),
            recorded_at: Map.fetch!(attrs, :recorded_at),
            summary: Map.fetch!(attrs, :summary),
            quantity: Map.get(attrs, :quantity),
            unit: Map.get(attrs, :unit),
            payload: Map.get(attrs, :payload, %{}),
            note: Map.get(attrs, :note)
          }
        )

      link =
        create!(
          __MODULE__,
          :create_event_item_link!,
          actor,
          %{
            plan_id: session_occurrence.plan_id,
            event_instance_id: event.id,
            item_id: item.id,
            role: role,
            metadata: Map.get(attrs, :link_metadata, %{})
          }
        )

      updated_slot_result = update_slot_result!(slot_result, item, event, actor)

      {{event, link, updated_slot_result}, take_notifications!()}
    end)
    |> case do
      {:ok, {{event, link, slot_result}, notifications}} ->
        Ash.Notifier.notify(notifications)
        %{event: event, event_item_link: link, slot_result: slot_result}

      {:error, error} ->
        raise inspect(error)
    end
  end

  def log_dose_event!(attrs, opts) do
    actor = Keyword.fetch!(opts, :actor)
    plan = Map.fetch!(attrs, :plan)
    event_type = Map.fetch!(attrs, :event_type)
    source_vial = Map.fetch!(attrs, :source_vial)

    result =
      log_generic_event!(
        dose_event_command_attrs(attrs, plan, event_type, source_vial),
        actor: actor
      )

    %{
      event: result.event,
      source_vial_link: List.first(result.event_item_links),
      item_effects: result.item_effects
    }
  end

  def correct_dose_event!(attrs, opts) do
    actor = Keyword.fetch!(opts, :actor)
    plan = Map.fetch!(attrs, :plan)
    event_type = Map.fetch!(attrs, :event_type)
    source_vial = Map.fetch!(attrs, :source_vial)
    original_event = Map.fetch!(attrs, :original_event)
    original_effect = Map.fetch!(attrs, :original_effect)

    Repo.transaction(fn ->
      reset_notifications!()

      corrected_at = Map.fetch!(attrs, :corrected_at)
      correction_note = Map.get(attrs, :correction_note, "Corrected by replacement event")

      corrected_event =
        create!(
          __MODULE__,
          :mark_event_corrected!,
          actor,
          original_event,
          %{
            voided_at: corrected_at,
            note: correction_note
          }
        )

      voided_effect =
        create!(
          __MODULE__,
          :void_item_effect!,
          actor,
          original_effect,
          %{voided_at: corrected_at}
        )

      replacement =
        attrs
        |> dose_event_command_attrs(plan, event_type, source_vial,
          default_summary: "Dose corrected",
          replaces_event_instance_id: original_event.id,
          replaces_item_effect_id: original_effect.id,
          link_metadata: %{"corrects_event_instance_id" => original_event.id}
        )
        |> LogEventCommand.from_attrs!()
        |> persist_log_event_command!(actor)

      result = %{
        corrected_event: corrected_event,
        voided_effect: voided_effect,
        replacement_event: replacement.event,
        replacement_link: List.first(replacement.event_item_links),
        replacement_effects: replacement.item_effects
      }

      {result, take_notifications!()}
    end)
    |> case do
      {:ok, {result, notifications}} ->
        Ash.Notifier.notify(notifications)
        result

      {:error, error} ->
        raise inspect(error)
    end
  end

  def read_journal(plan_or_id, opts) do
    actor = Keyword.fetch!(opts, :actor)

    with {:ok, plan} <- fetch_plan(plan_or_id, actor) do
      list_events(actor: actor, query: [filter: [plan_id: plan.id], sort: [effective_at: :asc]])
    end
  end

  def read_journal!(plan_or_id, opts) do
    case read_journal(plan_or_id, opts) do
      {:ok, events} -> events
      {:error, error} -> raise error
    end
  end

  def item_history(item_or_id, opts) do
    actor = Keyword.fetch!(opts, :actor)
    item_id = id(item_or_id)

    with {:ok, links} <- list_event_item_links(actor: actor, query: [filter: [item_id: item_id]]) do
      links
      |> Enum.map(&get_event!(&1.event_instance_id, actor: actor))
      |> Enum.sort_by(&DateTime.to_unix(&1.effective_at, :microsecond))
      |> then(&{:ok, &1})
    end
  end

  def item_history!(item_or_id, opts) do
    case item_history(item_or_id, opts) do
      {:ok, events} -> events
      {:error, error} -> raise error
    end
  end

  def get_item_state(item, opts) do
    actor = Keyword.fetch!(opts, :actor)

    with {:ok, item} <- Plans.get_item(id(item), actor: actor),
         {:ok, effects} <- list_item_effects(actor: actor, query: [filter: [item_id: item.id]]) do
      {:ok,
       Improve.Planning.ItemState.calculate(
         item,
         effects,
         Keyword.take(opts, [:future_quantity_required])
       )}
    end
  end

  def get_item_state!(item, opts) do
    case get_item_state(item, opts) do
      {:ok, state} -> state
      {:error, error} -> raise error
    end
  end

  defp effect_specs(event_type, payload, item_links) do
    result =
      EffectRuleInterpreter.interpret(%{
        rules: Map.get(event_type.effect_rules, "rules", []),
        item_links: item_links,
        payload: payload
      })

    case result.diagnostics do
      [] -> result.effects
      diagnostics -> raise Enum.join(diagnostics, " ")
    end
  end

  defp persist_log_event_command!(command, actor) do
    event =
      create!(
        __MODULE__,
        :log_event!,
        actor,
        LogEventCommand.to_event_attrs(command)
      )

    event_item_links =
      Enum.map(
        command.item_links,
        &create_event_item_link_from_command!(&1, command, event, actor)
      )

    event_type = Plans.get_event_type!(command.event_type_id, actor: actor)

    item_effects =
      event_type
      |> effect_specs(command.payload, command.item_links)
      |> Enum.map(
        &create_item_effect_from_spec!(&1, command.plan_id, event, actor,
          replaces_item_effect_id: command.replaces_item_effect_id
        )
      )

    slot_result = update_linked_slot_result(command, event, actor)

    %{
      event: event,
      event_item_links: event_item_links,
      item_effects: item_effects,
      slot_result: slot_result
    }
  end

  defp dose_event_command_attrs(attrs, plan, event_type, source_vial, opts \\ []) do
    %{
      plan_id: plan.id,
      event_type_id: event_type.id,
      effective_at: Map.fetch!(attrs, :effective_at),
      recorded_at: Map.fetch!(attrs, :recorded_at),
      summary: Map.get(attrs, :summary, Keyword.get(opts, :default_summary, "Dose recorded")),
      quantity: Map.fetch!(attrs, :amount),
      unit: Map.fetch!(attrs, :unit),
      payload: dose_payload(attrs),
      note: Map.get(attrs, :notes),
      replaces_event_instance_id: Keyword.get(opts, :replaces_event_instance_id),
      replaces_item_effect_id: Keyword.get(opts, :replaces_item_effect_id),
      item_links: [
        %{
          role: "source_vial",
          item_id: source_vial.id,
          metadata: Keyword.get(opts, :link_metadata, %{})
        }
      ]
    }
  end

  defp dose_payload(attrs) do
    %{
      "amount" => Map.fetch!(attrs, :amount),
      "unit" => Map.fetch!(attrs, :unit),
      "route" => Map.get(attrs, :route),
      "site" => Map.get(attrs, :site),
      "subjective_feedback" => Map.get(attrs, :subjective_feedback),
      "notes" => Map.get(attrs, :notes)
    }
  end

  defp create_item_effect_from_spec!(spec, plan_or_id, event, actor, opts) do
    create!(
      __MODULE__,
      :create_item_effect!,
      actor,
      %{
        plan_id: id(plan_or_id),
        item_id: Map.fetch!(spec, :item_id),
        event_instance_id: event.id,
        effect_type: Map.fetch!(spec, :effect_type),
        quantity: Map.get(spec, :quantity),
        unit: Map.get(spec, :unit),
        payload: Map.get(spec, :payload, %{}),
        replaces_item_effect_id: Keyword.get(opts, :replaces_item_effect_id)
      }
    )
  end

  defp create_event_item_link_from_command!(item_link, command, event, actor) do
    create!(
      __MODULE__,
      :create_event_item_link!,
      actor,
      %{
        plan_id: command.plan_id,
        event_instance_id: event.id,
        item_id: item_link.item_id,
        role: item_link.role,
        metadata: item_link.metadata
      }
    )
  end

  defp update_linked_slot_result(%{slot_result_id: nil}, _event, _actor), do: nil

  defp update_linked_slot_result(%{item_links: []}, _event, _actor), do: nil

  defp update_linked_slot_result(command, event, actor) do
    slot_result = Sessions.get_slot_result!(command.slot_result_id, actor: actor)
    [%{item_id: item_id} | _] = command.item_links
    update_slot_result!(slot_result, item_id, event, actor)
  end

  defp update_slot_result!(slot_result, %{id: item_id}, event, actor) do
    update_slot_result!(slot_result, item_id, event, actor)
  end

  defp update_slot_result!(slot_result, item_id, event, actor) do
    function =
      if slot_result.recommended_item_id == item_id do
        :complete_slot_result!
      else
        :swap_slot_result!
      end

    create!(
      Sessions,
      function,
      actor,
      slot_result,
      %{
        actual_item_id: item_id,
        event_instance_id: event.id
      }
    )
  end

  defp create!(domain, function, actor, attrs) do
    {record, notifications} =
      apply(domain, function, [
        attrs,
        [actor: actor, return_notifications?: true]
      ])

    collect_notifications!(notifications)
    record
  end

  defp create!(domain, function, actor, record, attrs) do
    {updated_record, notifications} =
      apply(domain, function, [
        record,
        attrs,
        [actor: actor, return_notifications?: true]
      ])

    collect_notifications!(notifications)
    updated_record
  end

  defp id(%{id: id}), do: id
  defp id(id), do: id

  defp fetch_plan(%{id: id}, actor), do: Plans.get_plan(id, actor: actor)
  defp fetch_plan(id, actor), do: Plans.get_plan(id, actor: actor)

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
