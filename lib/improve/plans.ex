defmodule Improve.Plans do
  use Ash.Domain,
    extensions: [AshTypescript.Rpc],
    otp_app: :improve

  typescript_rpc do
    resource Improve.Plans.Plan do
      rpc_action(:list_plans, :read)
      rpc_action(:get_plan, :read, get_by: [:id])
    end

    resource Improve.Plans.Item do
      rpc_action(:list_items, :read)
      rpc_action(:get_item, :read, get_by: [:id])
    end
  end

  resources do
    resource Improve.Plans.Plan do
      define :create_plan, action: :create
      define :get_plan, action: :read, get_by: [:id]
      define :list_plans, action: :read
      define :archive_plan, action: :archive
      define :extend_plan, action: :extend_plan
    end

    resource Improve.Plans.ItemType do
      define :create_item_type, action: :create
      define :get_item_type, action: :read, get_by: [:id]
      define :list_item_types, action: :read
    end

    resource Improve.Plans.Item do
      define :create_item, action: :create
      define :get_item, action: :read, get_by: [:id]
      define :list_items, action: :read
      define :archive_item, action: :archive
    end

    resource Improve.Plans.Pool do
      define :create_pool, action: :create
      define :get_pool, action: :read, get_by: [:id]
      define :list_pools, action: :read
    end

    resource Improve.Plans.PoolMembership do
      define :create_pool_membership, action: :create
      define :list_pool_memberships, action: :read
    end

    resource Improve.Plans.Environment do
      define :create_environment, action: :create
      define :get_environment, action: :read, get_by: [:id]
      define :list_environments, action: :read
    end

    resource Improve.Plans.EventType do
      define :create_event_type, action: :create
      define :get_event_type, action: :read, get_by: [:id]
      define :list_event_types, action: :read
    end

    resource Improve.Plans.Schedule do
      define :create_schedule, action: :create
      define :update_schedule, action: :update
      define :get_schedule, action: :read, get_by: [:id]
      define :list_schedules, action: :read
    end

    resource Improve.Plans.TimeOffWindow do
      define :create_time_off_window, action: :create
      define :get_time_off_window, action: :read, get_by: [:id]
      define :list_time_off_windows, action: :read
    end

    resource Improve.Plans.Customization do
      define :create_customization, action: :create
      define :update_customization, action: :update
      define :get_customization, action: :read, get_by: [:id]
      define :list_customizations, action: :read
    end

    resource Improve.Plans.SessionTemplate do
      define :create_session_template, action: :create
      define :get_session_template, action: :read, get_by: [:id]
      define :list_session_templates, action: :read
    end

    resource Improve.Plans.SessionSlot do
      define :create_session_slot, action: :create
      define :get_session_slot, action: :read, get_by: [:id]
      define :list_session_slots, action: :read
      define :update_session_slot, action: :update
    end

    resource Improve.Plans.Track do
      define :create_track, action: :create
      define :update_track, action: :update
      define :get_track, action: :read, get_by: [:id]
      define :list_tracks, action: :read
    end
  end

  def summarize_plan(plan_or_id, opts) do
    actor = Keyword.fetch!(opts, :actor)

    with {:ok, plan} <- fetch_plan(plan_or_id, actor),
         {:ok, plan} <- Ash.load(plan, summary_aggregates(), actor: actor) do
      {:ok, summary_from_aggregates(plan)}
    end
  end

  def summarize_plan!(plan_or_id, opts) do
    case summarize_plan(plan_or_id, opts) do
      {:ok, summary} -> summary
      {:error, error} -> raise error
    end
  end

  def export_plan_draft(plan_or_id, opts) do
    Improve.Planning.PlanDraftExporter.export(plan_or_id, opts)
  end

  def export_plan_draft!(plan_or_id, opts) do
    Improve.Planning.PlanDraftExporter.export!(plan_or_id, opts)
  end

  def import_plan_draft(draft, opts) do
    Improve.Planning.PlanDraftImporter.import_draft(draft, opts)
  end

  def import_plan_draft!(draft, opts) do
    Improve.Planning.PlanDraftImporter.import_draft!(draft, opts)
  end

  def preview_plan_draft(draft) do
    Improve.Planning.PlanDraftPreview.preview(draft)
  end

  def project_today(plan_or_id, opts) do
    actor = Keyword.fetch!(opts, :actor)
    date = Keyword.fetch!(opts, :date)

    with {:ok, plan} <- fetch_plan(plan_or_id, actor),
         {:ok, input} <- projection_input(plan, actor, date, opts) do
      {:ok, Improve.Planning.Projector.project_today(input)}
    end
  end

  def project_today!(plan_or_id, opts) do
    case project_today(plan_or_id, opts) do
      {:ok, projection} -> projection
      {:error, error} -> raise error
    end
  end

  defp fetch_plan(%{id: id}, actor), do: get_plan(id, actor: actor)
  defp fetch_plan(id, actor), do: get_plan(id, actor: actor)

  defp projection_input(plan, actor, date, opts) do
    with {:ok, plan} <- Ash.load(plan, projection_load(), actor: actor) do
      {:ok,
       %{
         date: date,
         plan: plan,
         session_templates: plan.session_templates,
         session_slots: plan.session_slots,
         schedules: plan.schedules,
         time_off_windows: plan.time_off_windows,
         tracks: plan.tracks,
         journal_events: plan.event_instances,
         session_occurrences: plan.session_occurrences,
         slot_results: plan.slot_results,
         items: plan.items,
         pool_memberships: plan.pool_memberships,
         environments: plan.environments,
         as_of_date: Keyword.get(opts, :as_of_date, date),
         recent_item_ids: Keyword.get(opts, :recent_item_ids, [])
       }}
    end
  end

  defp summary_aggregates do
    [
      :item_type_count,
      :item_count,
      :pool_count,
      :pool_membership_count,
      :environment_count,
      :event_type_count,
      :session_template_count,
      :session_slot_count,
      :track_count,
      :schedule_count
    ]
  end

  defp summary_from_aggregates(plan) do
    %{
      item_types: plan.item_type_count,
      items: plan.item_count,
      pools: plan.pool_count,
      pool_memberships: plan.pool_membership_count,
      environments: plan.environment_count,
      event_types: plan.event_type_count,
      session_templates: plan.session_template_count,
      session_slots: plan.session_slot_count,
      tracks: plan.track_count,
      schedules: plan.schedule_count
    }
  end

  defp projection_load do
    [
      :session_templates,
      :session_slots,
      :schedules,
      :time_off_windows,
      :tracks,
      :session_occurrences,
      :slot_results,
      :items,
      :pool_memberships,
      :environments,
      event_instances: [:event_item_links]
    ]
  end
end
