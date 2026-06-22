defmodule Improve.Journal do
  use Ash.Domain,
    otp_app: :improve

  alias Improve.Repo
  alias Improve.Sessions

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

  def read_journal(plan_or_id, opts) do
    actor = Keyword.fetch!(opts, :actor)
    plan_id = id(plan_or_id)

    list_events(actor: actor, query: [filter: [plan_id: plan_id], sort: [effective_at: :asc]])
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
