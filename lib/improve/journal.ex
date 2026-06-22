defmodule Improve.Journal do
  use Ash.Domain,
    extensions: [AshTypescript.Rpc],
    otp_app: :improve

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

    payload = %{
      "amount" => Map.fetch!(attrs, :amount),
      "unit" => Map.fetch!(attrs, :unit),
      "route" => Map.get(attrs, :route),
      "site" => Map.get(attrs, :site),
      "subjective_feedback" => Map.get(attrs, :subjective_feedback),
      "notes" => Map.get(attrs, :notes)
    }

    Repo.transaction(fn ->
      reset_notifications!()

      event =
        create!(
          __MODULE__,
          :log_event!,
          actor,
          %{
            plan_id: plan.id,
            event_type_id: event_type.id,
            effective_at: Map.fetch!(attrs, :effective_at),
            recorded_at: Map.fetch!(attrs, :recorded_at),
            summary: Map.get(attrs, :summary, "Dose recorded"),
            quantity: Map.fetch!(attrs, :amount),
            unit: Map.fetch!(attrs, :unit),
            payload: payload,
            note: Map.get(attrs, :notes)
          }
        )

      source_vial_link =
        create!(
          __MODULE__,
          :create_event_item_link!,
          actor,
          %{
            plan_id: plan.id,
            event_instance_id: event.id,
            item_id: source_vial.id,
            role: "source_vial",
            metadata: %{}
          }
        )

      effects =
        event_type
        |> effect_specs(payload, [%{role: "source_vial", item_id: source_vial.id}])
        |> Enum.map(&create_item_effect_from_spec!(&1, plan, event, actor))

      {{event, source_vial_link, effects}, take_notifications!()}
    end)
    |> case do
      {:ok, {{event, source_vial_link, effects}, notifications}} ->
        Ash.Notifier.notify(notifications)
        %{event: event, source_vial_link: source_vial_link, item_effects: effects}

      {:error, error} ->
        raise inspect(error)
    end
  end

  def correct_dose_event!(attrs, opts) do
    actor = Keyword.fetch!(opts, :actor)
    plan = Map.fetch!(attrs, :plan)
    event_type = Map.fetch!(attrs, :event_type)
    source_vial = Map.fetch!(attrs, :source_vial)
    original_event = Map.fetch!(attrs, :original_event)
    original_effect = Map.fetch!(attrs, :original_effect)

    payload = %{
      "amount" => Map.fetch!(attrs, :amount),
      "unit" => Map.fetch!(attrs, :unit),
      "route" => Map.get(attrs, :route),
      "site" => Map.get(attrs, :site),
      "subjective_feedback" => Map.get(attrs, :subjective_feedback),
      "notes" => Map.get(attrs, :notes)
    }

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

      replacement_event =
        create!(
          __MODULE__,
          :log_event!,
          actor,
          %{
            plan_id: plan.id,
            event_type_id: event_type.id,
            effective_at: Map.fetch!(attrs, :effective_at),
            recorded_at: Map.fetch!(attrs, :recorded_at),
            summary: Map.get(attrs, :summary, "Dose corrected"),
            quantity: Map.fetch!(attrs, :amount),
            unit: Map.fetch!(attrs, :unit),
            payload: payload,
            note: Map.get(attrs, :notes),
            replaces_event_instance_id: original_event.id
          }
        )

      replacement_link =
        create!(
          __MODULE__,
          :create_event_item_link!,
          actor,
          %{
            plan_id: plan.id,
            event_instance_id: replacement_event.id,
            item_id: source_vial.id,
            role: "source_vial",
            metadata: %{"corrects_event_instance_id" => original_event.id}
          }
        )

      replacement_effects =
        event_type
        |> effect_specs(payload, [%{role: "source_vial", item_id: source_vial.id}])
        |> Enum.map(
          &create_item_effect_from_spec!(&1, plan, replacement_event, actor,
            replaces_item_effect_id: original_effect.id
          )
        )

      result = %{
        corrected_event: corrected_event,
        voided_effect: voided_effect,
        replacement_event: replacement_event,
        replacement_link: replacement_link,
        replacement_effects: replacement_effects
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

  defp create_item_effect_from_spec!(spec, plan, event, actor, opts \\ []) do
    create!(
      __MODULE__,
      :create_item_effect!,
      actor,
      %{
        plan_id: plan.id,
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

  defp update_slot_result!(slot_result, item, event, actor) do
    function =
      if slot_result.recommended_item_id == item.id do
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
        actual_item_id: item.id,
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
