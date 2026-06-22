defmodule Improve.Accounts.User do
  use Ash.Resource,
    otp_app: :improve,
    domain: Improve.Accounts,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "users"
    repo Improve.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:email, :full_name]
    end

    update :update do
      primary? true
      accept [:email, :full_name]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :string do
      allow_nil? false
      public? true
      constraints match: ~r/^[^\s]+@[^\s]+$/
    end

    attribute :full_name, :string do
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at, public?: true
    update_timestamp :updated_at, public?: true
  end

  relationships do
    has_many :plans, Improve.Plans.Plan
  end

  identities do
    identity :unique_email, [:email]
  end
end
