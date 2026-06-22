defmodule Improve.Plans.SessionTemplate do
  use Ash.Resource,
    otp_app: :improve,
    domain: Improve.Plans,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "session_templates"
    repo Improve.Repo
  end

  actions do
    defaults [:read]

    create :create do
      primary? true

      accept [
        :plan_id,
        :key,
        :name,
        :description,
        :environment_id,
        :completion_policy,
        :missed_policy
      ]
    end

    update :update do
      primary? true
      accept [:key, :name, :description, :environment_id, :completion_policy, :missed_policy]
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

    attribute :description, :string do
      public? true
    end

    attribute :completion_policy, :map do
      allow_nil? false
      public? true
      default %{}
    end

    attribute :missed_policy, :map do
      allow_nil? false
      public? true
      default %{}
    end

    create_timestamp :inserted_at, public?: true
    update_timestamp :updated_at, public?: true
  end

  relationships do
    belongs_to :plan, Improve.Plans.Plan do
      allow_nil? false
      public? true
    end

    belongs_to :environment, Improve.Plans.Environment do
      public? true
    end

    has_many :session_slots, Improve.Plans.SessionSlot
    has_many :session_occurrences, Improve.Sessions.SessionOccurrence
  end

  identities do
    identity :unique_key_per_plan, [:plan_id, :key]
  end
end
