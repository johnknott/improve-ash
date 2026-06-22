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
      define :get_schedule, action: :read, get_by: [:id]
      define :list_schedules, action: :read
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
    end

    resource Improve.Plans.DirectGoal do
      define :create_direct_goal, action: :create
      define :get_direct_goal, action: :read, get_by: [:id]
      define :list_direct_goals, action: :read
    end
  end

  def summarize_plan(plan_or_id, opts) do
    actor = Keyword.fetch!(opts, :actor)

    with {:ok, plan} <- fetch_plan(plan_or_id, actor),
         plan_filter = [filter: [plan_id: plan.id]],
         {:ok, item_types} <- list_item_types(actor: actor, query: plan_filter),
         {:ok, items} <- list_items(actor: actor, query: plan_filter),
         {:ok, pools} <- list_pools(actor: actor, query: plan_filter),
         {:ok, pool_memberships} <- list_pool_memberships(actor: actor, query: plan_filter),
         {:ok, environments} <- list_environments(actor: actor, query: plan_filter),
         {:ok, event_types} <- list_event_types(actor: actor, query: plan_filter),
         {:ok, session_templates} <- list_session_templates(actor: actor, query: plan_filter),
         {:ok, session_slots} <- list_session_slots(actor: actor, query: plan_filter),
         {:ok, schedules} <- list_schedules(actor: actor, query: plan_filter) do
      {:ok,
       %{
         item_types: length(item_types),
         items: length(items),
         pools: length(pools),
         pool_memberships: length(pool_memberships),
         environments: length(environments),
         event_types: length(event_types),
         session_templates: length(session_templates),
         session_slots: length(session_slots),
         schedules: length(schedules)
       }}
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
    plan_filter = [filter: [plan_id: plan.id]]

    with {:ok, session_templates} <- list_session_templates(actor: actor, query: plan_filter),
         {:ok, session_slots} <- list_session_slots(actor: actor, query: plan_filter),
         {:ok, schedules} <- list_schedules(actor: actor, query: plan_filter),
         {:ok, direct_goals} <- list_direct_goals(actor: actor, query: plan_filter),
         {:ok, journal_events} <- Improve.Journal.list_events(actor: actor, query: plan_filter),
         {:ok, session_occurrences} <-
           Improve.Sessions.list_session_occurrences(actor: actor, query: plan_filter),
         {:ok, items} <- list_items(actor: actor, query: plan_filter),
         {:ok, pool_memberships} <- list_pool_memberships(actor: actor, query: plan_filter),
         {:ok, environments} <- list_environments(actor: actor, query: plan_filter) do
      {:ok,
       %{
         date: date,
         plan: plan,
         session_templates: session_templates,
         session_slots: session_slots,
         schedules: schedules,
         direct_goals: direct_goals,
         journal_events: journal_events,
         session_occurrences: session_occurrences,
         items: items,
         pool_memberships: pool_memberships,
         environments: environments,
         as_of_date: Keyword.get(opts, :as_of_date, date),
         recent_item_ids: Keyword.get(opts, :recent_item_ids, [])
       }}
    end
  end
end
