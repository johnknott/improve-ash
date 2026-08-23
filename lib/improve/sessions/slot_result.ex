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
        :suggested_payload,
        :actual_payload,
        :status,
        :event_instance_id,
        :notes
      ]

      validate {Improve.Validations.SamePlan,
                references: [
                  session_occurrence_id: Improve.Sessions.SessionOccurrence,
                  session_slot_id: Improve.Plans.SessionSlot,
                  recommended_item_id: Improve.Plans.Item,
                  actual_item_id: Improve.Plans.Item,
                  event_instance_id: Improve.Journal.EventInstance
                ]}
    end

    update :complete do
      accept [:actual_item_id, :actual_payload, :event_instance_id, :notes]

      validate data_one_of(:status, [:planned, :swapped]) do
        message "can only be completed from planned or swapped"
      end

      change set_attribute(:status, :completed)

      validate {Improve.Validations.SamePlan,
                references: [
                  session_occurrence_id: Improve.Sessions.SessionOccurrence,
                  session_slot_id: Improve.Plans.SessionSlot,
                  recommended_item_id: Improve.Plans.Item,
                  actual_item_id: Improve.Plans.Item,
                  event_instance_id: Improve.Journal.EventInstance
                ]}
    end

    update :swap do
      accept [:actual_item_id, :actual_payload, :event_instance_id, :notes]

      validate data_one_of(:status, [:planned, :swapped]) do
        message "can only be swapped from planned or swapped"
      end

      change set_attribute(:status, :swapped)

      validate {Improve.Validations.SamePlan,
                references: [
                  session_occurrence_id: Improve.Sessions.SessionOccurrence,
                  session_slot_id: Improve.Plans.SessionSlot,
                  recommended_item_id: Improve.Plans.Item,
                  actual_item_id: Improve.Plans.Item,
                  event_instance_id: Improve.Journal.EventInstance
                ]}
    end

    update :correct do
      argument :expected_event_instance_id, :uuid, allow_nil?: false

      accept [:actual_payload, :event_instance_id, :notes]

      validate data_one_of(:status, [:completed, :swapped]) do
        message "can only be corrected after it has been logged"
      end

      change filter(expr(event_instance_id == ^arg(:expected_event_instance_id)))

      validate {Improve.Validations.SamePlan,
                references: [
                  session_occurrence_id: Improve.Sessions.SessionOccurrence,
                  session_slot_id: Improve.Plans.SessionSlot,
                  recommended_item_id: Improve.Plans.Item,
                  actual_item_id: Improve.Plans.Item,
                  event_instance_id: Improve.Journal.EventInstance
                ]}
    end

    update :skip do
      accept [:actual_payload, :notes]

      validate data_one_of(:status, [:planned, :swapped]) do
        message "can only be skipped from planned or swapped"
      end

      change set_attribute(:status, :skipped)
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
      constraints one_of: [:planned, :completed, :skipped, :swapped]
    end

    attribute :notes, :string do
      public? true
    end

    attribute :suggested_payload, :map do
      allow_nil? false
      public? true
      default %{}
    end

    attribute :actual_payload, :map do
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
