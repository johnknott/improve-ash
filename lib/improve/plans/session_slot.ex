defmodule Improve.Plans.SessionSlot do
  use Ash.Resource,
    otp_app: :improve,
    domain: Improve.Plans,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "session_slots"
    repo Improve.Repo
  end

  actions do
    defaults [:read]

    create :create do
      primary? true

      accept [
        :plan_id,
        :session_template_id,
        :key,
        :name,
        :pool_id,
        :count,
        :optional,
        :rules,
        :position
      ]
    end

    update :update do
      primary? true
      accept [:key, :name, :pool_id, :count, :optional, :rules, :position]
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

  validations do
    validate compare(:count, greater_than: 0)
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

    attribute :count, :integer do
      allow_nil? false
      public? true
      default 1
    end

    attribute :optional, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :rules, :map do
      allow_nil? false
      public? true
      default %{}
    end

    attribute :position, :integer do
      allow_nil? false
      public? true
      default 0
    end

    create_timestamp :inserted_at, public?: true
    update_timestamp :updated_at, public?: true
  end

  relationships do
    belongs_to :plan, Improve.Plans.Plan do
      allow_nil? false
      public? true
    end

    belongs_to :session_template, Improve.Plans.SessionTemplate do
      allow_nil? false
      public? true
    end

    belongs_to :pool, Improve.Plans.Pool do
      allow_nil? false
      public? true
    end

    has_many :slot_results, Improve.Sessions.SlotResult
  end

  identities do
    identity :unique_key_per_template, [:session_template_id, :key]
  end
end
