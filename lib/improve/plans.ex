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
  end
end
