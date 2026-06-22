defmodule Improve.Journal.EventItemLink do
  use Ash.Resource,
    otp_app: :improve,
    domain: Improve.Journal,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "event_item_links"
    repo Improve.Repo
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:plan_id, :event_instance_id, :item_id, :role, :metadata]
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(plan.user_id == ^actor(:id))
    end

    policy action_type(:create) do
      authorize_if expr(plan.user_id == ^actor(:id))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :role, :string do
      allow_nil? false
      public? true
    end

    attribute :metadata, :map do
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

    belongs_to :event_instance, Improve.Journal.EventInstance do
      allow_nil? false
      public? true
    end

    belongs_to :item, Improve.Plans.Item do
      allow_nil? false
      public? true
    end
  end
end
