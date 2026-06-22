defmodule Improve.Sessions.SlotResult do
  use Ash.Resource,
    otp_app: :improve,
    domain: Improve.Sessions,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "slot_results"
    repo Improve.Repo
  end

  actions do
    defaults [:read]

    create :create do
      primary? true

      accept [
        :plan_id,
        :session_occurrence_id,
        :session_slot_id,
        :recommended_item_id,
        :actual_item_id,
        :status,
        :event_instance_id,
        :notes
      ]
    end

    update :complete do
      accept [:actual_item_id, :event_instance_id, :notes]
      change set_attribute(:status, :completed)
    end

    update :swap do
      accept [:actual_item_id, :event_instance_id, :notes]
      change set_attribute(:status, :swapped)
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

    attribute :status, :atom do
      allow_nil? false
      public? true
      default :planned
      constraints one_of: [:planned, :completed, :skipped, :partially_completed, :swapped]
    end

    attribute :notes, :string do
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

    belongs_to :session_occurrence, Improve.Sessions.SessionOccurrence do
      allow_nil? false
      public? true
    end

    belongs_to :session_slot, Improve.Plans.SessionSlot do
      allow_nil? false
      public? true
    end

    belongs_to :recommended_item, Improve.Plans.Item do
      public? true
    end

    belongs_to :actual_item, Improve.Plans.Item do
      public? true
    end

    belongs_to :event_instance, Improve.Journal.EventInstance do
      public? true
    end
  end
end
