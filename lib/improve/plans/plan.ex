defmodule Improve.Plans.Plan do
  use Ash.Resource,
    otp_app: :improve,
    domain: Improve.Plans,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshTypescript.Resource],
    authorizers: [Ash.Policy.Authorizer]

  typescript do
    type_name("Plan")
  end

  postgres do
    table "plans"
    repo Improve.Repo
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:name, :intention, :starts_on, :ends_on, :status, :source_kind, :source_key]
      change relate_actor(:user)
    end

    update :update do
      primary? true
      accept [:name, :intention, :starts_on, :ends_on, :status, :source_kind, :source_key]
    end

    update :archive do
      accept []
      change set_attribute(:status, :archived)
    end
  end

  policies do
    policy action_type(:read) do
      description "Users can read only their own plans."
      authorize_if relates_to_actor_via(:user)
    end

    policy action_type(:create) do
      description "Users can create plans for themselves."
      authorize_if always()
    end

    policy action_type(:update) do
      description "Users can update only their own plans."
      authorize_if relates_to_actor_via(:user)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :intention, :string do
      allow_nil? false
      public? true
    end

    attribute :starts_on, :date do
      allow_nil? false
      public? true
    end

    attribute :ends_on, :date do
      allow_nil? false
      public? true
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      default :draft
      constraints one_of: [:draft, :active, :archived]
    end

    attribute :source_kind, :atom do
      allow_nil? false
      public? true
      default :manual
      constraints one_of: [:manual, :demo, :imported]
    end

    attribute :source_key, :string do
      public? true
    end

    create_timestamp :inserted_at, public?: true
    update_timestamp :updated_at, public?: true
  end

  relationships do
    belongs_to :user, Improve.Accounts.User do
      allow_nil? false
      public? true
    end

    has_many :item_types, Improve.Plans.ItemType
    has_many :items, Improve.Plans.Item
    has_many :pools, Improve.Plans.Pool
    has_many :pool_memberships, Improve.Plans.PoolMembership
    has_many :environments, Improve.Plans.Environment
    has_many :event_types, Improve.Plans.EventType
    has_many :schedules, Improve.Plans.Schedule
    has_many :session_templates, Improve.Plans.SessionTemplate
    has_many :session_slots, Improve.Plans.SessionSlot
    has_many :direct_goals, Improve.Plans.DirectGoal
    has_many :session_occurrences, Improve.Sessions.SessionOccurrence
    has_many :event_instances, Improve.Journal.EventInstance
  end
end
