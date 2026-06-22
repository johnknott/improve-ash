defmodule Improve.Journal.EventInstance do
  use Ash.Resource,
    otp_app: :improve,
    domain: Improve.Journal,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshTypescript.Resource],
    authorizers: [Ash.Policy.Authorizer]

  typescript do
    type_name("EventInstance")
  end

  postgres do
    table "event_instances"
    repo Improve.Repo
  end

  actions do
    defaults [:read]

    create :log do
      primary? true

      accept [
        :plan_id,
        :event_type_id,
        :session_occurrence_id,
        :slot_result_id,
        :direct_goal_id,
        :effective_at,
        :recorded_at,
        :summary,
        :quantity,
        :unit,
        :payload,
        :note,
        :status,
        :origin,
        :replaces_event_instance_id
      ]
    end

    update :void do
      accept [:voided_at, :note]
      change set_attribute(:status, :voided)
    end

    update :mark_corrected do
      accept [:voided_at, :note]
      change set_attribute(:status, :corrected)
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

    attribute :effective_at, :utc_datetime_usec do
      allow_nil? false
      public? true
    end

    attribute :recorded_at, :utc_datetime_usec do
      allow_nil? false
      public? true
    end

    attribute :summary, :string do
      allow_nil? false
      public? true
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

    attribute :note, :string do
      public? true
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      default :active
      constraints one_of: [:active, :voided, :corrected]
    end

    attribute :origin, :atom do
      allow_nil? false
      public? true
      default :manual
      constraints one_of: [:manual, :seed, :assistant_proposed, :imported, :offline_sync]
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

    belongs_to :event_type, Improve.Plans.EventType do
      allow_nil? false
      public? true
    end

    belongs_to :session_occurrence, Improve.Sessions.SessionOccurrence do
      public? true
    end

    belongs_to :slot_result, Improve.Sessions.SlotResult do
      public? true
    end

    belongs_to :direct_goal, Improve.Plans.DirectGoal do
      public? true
    end

    belongs_to :replaces_event_instance, Improve.Journal.EventInstance do
      public? true
    end

    has_many :event_item_links, Improve.Journal.EventItemLink
    has_many :item_effects, Improve.Journal.ItemEffect
  end
end
