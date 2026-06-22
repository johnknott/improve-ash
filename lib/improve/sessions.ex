defmodule Improve.Sessions do
  use Ash.Domain,
    extensions: [AshTypescript.Rpc],
    otp_app: :improve

  alias Improve.CommandError
  alias Improve.Repo

  typescript_rpc do
    resource Improve.Sessions.SessionOccurrence do
      rpc_action(:list_session_occurrences, :read)
      rpc_action(:get_session_occurrence, :read, get_by: [:id])
    end
  end

  resources do
    resource Improve.Sessions.SessionOccurrence do
      define :create_session_occurrence, action: :create_projected
      define :get_session_occurrence, action: :read, get_by: [:id]
      define :list_session_occurrences, action: :read
      define :start_session_occurrence, action: :start
      define :complete_session_occurrence, action: :complete
      define :mark_session_occurrence_skipped, action: :mark_skipped
      define :mark_session_occurrence_missed, action: :mark_missed
    end

    resource Improve.Sessions.SlotResult do
      define :create_slot_result, action: :create
      define :get_slot_result, action: :read, get_by: [:id]
      define :list_slot_results, action: :read
      define :complete_slot_result, action: :complete
      define :swap_slot_result, action: :swap
    end
  end

  @notifications_key {__MODULE__, :notifications}

  def start_projected_session!(projected_occurrence, opts) do
    CommandError.wrap!(:start_projected_session, fn ->
      actor = Keyword.fetch!(opts, :actor)
      started_at = Keyword.fetch!(opts, :started_at)
      actual_item_ids_by_slot_key = Keyword.get(opts, :actual_item_ids_by_slot_key, %{})

      Repo.transaction(fn ->
        reset_notifications!()

        occurrence =
          create!(
            :create_session_occurrence!,
            actor,
            %{
              plan_id: projected_occurrence.plan_id,
              session_template_id: projected_occurrence.session_template_id,
              planned_for: projected_occurrence.planned_for,
              status: :started,
              started_at: started_at,
              recommendation_snapshot: snapshot(projected_occurrence)
            }
          )

        slot_results =
          projected_occurrence.recommendations
          |> Enum.flat_map(&slot_result_attrs(&1, occurrence, actual_item_ids_by_slot_key))
          |> Enum.map(&create!(:create_slot_result!, actor, &1))

        {{occurrence, slot_results}, take_notifications!()}
      end)
      |> case do
        {:ok, {{occurrence, slot_results}, notifications}} ->
          Ash.Notifier.notify(notifications)
          %{session_occurrence: occurrence, slot_results: slot_results}

        {:error, error} ->
          CommandError.raise!(:start_projected_session, error)
      end
    end)
  end

  defp slot_result_attrs(recommendation, occurrence, actual_item_ids_by_slot_key) do
    actual_item_ids = Map.get(actual_item_ids_by_slot_key, recommendation.slot_key, [])

    recommendation.recommended_items
    |> Enum.with_index()
    |> Enum.map(fn {recommended_item, index} ->
      actual_item_id = Enum.at(actual_item_ids, index, recommended_item.item_id)

      %{
        plan_id: occurrence.plan_id,
        session_occurrence_id: occurrence.id,
        session_slot_id: recommendation.session_slot_id,
        recommended_item_id: recommended_item.item_id,
        actual_item_id: actual_item_id,
        status: slot_status(recommended_item.item_id, actual_item_id)
      }
    end)
  end

  defp slot_status(recommended_item_id, actual_item_id)
       when recommended_item_id == actual_item_id, do: :planned

  defp slot_status(_recommended_item_id, _actual_item_id), do: :swapped

  defp snapshot(projected_occurrence) do
    %{
      "session_template_name" => projected_occurrence.session_template_name,
      "planned_for" => Date.to_iso8601(projected_occurrence.planned_for),
      "recommendations" =>
        Enum.map(projected_occurrence.recommendations, fn recommendation ->
          %{
            "session_slot_id" => recommendation.session_slot_id,
            "slot_key" => recommendation.slot_key,
            "slot_name" => recommendation.slot_name,
            "count" => recommendation.count,
            "recommended_items" =>
              Enum.map(recommendation.recommended_items, fn item ->
                %{
                  "item_id" => item.item_id,
                  "item_key" => item.item_key,
                  "item_name" => item.item_name
                }
              end)
          }
        end)
    }
  end

  defp create!(function, actor, attrs) do
    {record, notifications} =
      apply(__MODULE__, function, [
        attrs,
        [actor: actor, return_notifications?: true]
      ])

    collect_notifications!(notifications)
    record
  end

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
