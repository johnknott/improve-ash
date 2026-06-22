defmodule Improve.Plans.Environment do
  use Ash.Resource,
    otp_app: :improve,
    domain: Improve.Plans,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "environments"
    repo Improve.Repo
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:plan_id, :key, :name, :description, :available_item_ids]

      validate {Improve.Validations.SamePlan,
                array_references: [
                  available_item_ids: Improve.Plans.Item
                ]}
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:key, :name, :description, :available_item_ids]

      validate {Improve.Validations.SamePlan,
                array_references: [
                  available_item_ids: Improve.Plans.Item
                ]}
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

    attribute :available_item_ids, {:array, :uuid} do
      allow_nil? false
      public? true
      default []
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
