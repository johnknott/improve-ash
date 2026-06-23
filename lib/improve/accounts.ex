defmodule Improve.Accounts do
  use Ash.Domain,
    otp_app: :improve

  resources do
    resource Improve.Accounts.Token

    resource Improve.Accounts.User do
      define :create_user, action: :create
      define :get_user, action: :read, get_by: [:id]
      define :get_user_by_email, action: :read, get_by_identity: :unique_email
      define :list_users, action: :read
      define :complete_profile, action: :complete_profile
    end
  end
end
