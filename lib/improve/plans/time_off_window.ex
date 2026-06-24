defmodule Improve.Plans.TimeOffWindow do
  use Ash.Resource,
    otp_app: :improve,
    domain: Improve.Plans,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "time_off_windows"
    repo Improve.Repo
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:plan_id, :key, :kind, :reason, :starts_on, :ends_on, :availability]
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:key, :kind, :reason, :starts_on, :ends_on, :availability]
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

    attribute :kind, :atom do
      allow_nil? false
      public? true
      default :other
      constraints one_of: [:holiday, :travel, :work, :recovery, :other]
    end

    attribute :reason, :string do
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

    attribute :availability, :atom do
      allow_nil? false
      public? true
      default :fully_off
      constraints one_of: [:fully_off, :limited, :available]
    end

    create_timestamp :inserted_at, public?: true
    update_timestamp :updated_at, public?: true
  end

  relationships do
    belongs_to :plan, Improve.Plans.Plan do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_key_per_plan, [:plan_id, :key]
  end
end
