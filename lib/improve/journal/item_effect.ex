defmodule Improve.Journal.ItemEffect do
  use Ash.Resource,
    otp_app: :improve,
    domain: Improve.Journal,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshTypescript.Resource],
    authorizers: [Ash.Policy.Authorizer]

  typescript do
    type_name("ItemEffect")
  end

  postgres do
    table "item_effects"
    repo Improve.Repo
  end

  actions do
    defaults [:read]

    create :create do
      primary? true

      accept [
        :plan_id,
        :item_id,
        :event_instance_id,
        :effect_type,
        :quantity,
        :unit,
        :payload,
        :status,
        :replaces_item_effect_id
      ]

      validate {Improve.Validations.SamePlan,
                references: [
                  item_id: Improve.Plans.Item,
                  event_instance_id: Improve.Journal.EventInstance,
                  replaces_item_effect_id: Improve.Journal.ItemEffect
                ]}
    end

    update :void do
      accept [:voided_at]

      validate data_one_of(:status, [:active]) do
        message "can only be voided from active"
      end

      change set_attribute(:status, :voided)
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

    attribute :effect_type, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :add_quantity,
                    :subtract_quantity,
                    :set_quantity,
                    :set_fact,
                    :correction
                  ]
    end

    attribute :quantity, :decimal do
      public? true
    end

    attribute :unit, :string do
      public? true
    end

    attribute :payload, :map do
      allow_nil? false
      public? true
      default %{}
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      default :active
      constraints one_of: [:active, :voided]
    end

    attribute :voided_at, :utc_datetime_usec do
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

    belongs_to :item, Improve.Plans.Item do
      allow_nil? false
      public? true
    end

    belongs_to :event_instance, Improve.Journal.EventInstance do
      allow_nil? false
      public? true
    end

    belongs_to :replaces_item_effect, Improve.Journal.ItemEffect do
      public? true
    end
  end
end
