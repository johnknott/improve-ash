defmodule Improve.Plans.Item do
  use Ash.Resource,
    otp_app: :improve,
    domain: Improve.Plans,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "items"
    repo Improve.Repo
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:plan_id, :item_type_id, :key, :name, :facts, :stateful]
    end

    update :update do
      primary? true
      accept [:key, :name, :facts, :stateful]
    end

    update :archive do
      accept []
      change set_attribute(:archived_at, &DateTime.utc_now/0)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(plan.user_id == ^actor(:id))
    end

    policy action_type([:create, :update]) do
      authorize_if expr(plan.user_id == ^actor(:id))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :key, :string do
      allow_nil? false
      public? true
    end

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :facts, :map do
      allow_nil? false
      public? true
      default %{}
    end

    attribute :stateful, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :archived_at, :utc_datetime_usec do
      public? true
    end

    create_timestamp :inserted_at, public?: true
    update_timestamp :updated_at, public?: true
  end

  relationships do
    belongs_to :plan, Improve.Plans.Plan do
      allow_nil? false
      public? true
    end

    belongs_to :item_type, Improve.Plans.ItemType do
      allow_nil? false
      public? true
    end

    has_many :pool_memberships, Improve.Plans.PoolMembership
  end

  identities do
    identity :unique_key_per_plan, [:plan_id, :key]
  end
end
