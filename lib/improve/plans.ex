defmodule Improve.Plans do
  use Ash.Domain,
    otp_app: :improve

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
  end
end
