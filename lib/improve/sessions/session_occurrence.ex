defmodule Improve.Sessions.SessionOccurrence do
  use Ash.Resource,
    otp_app: :improve,
    domain: Improve.Sessions,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshTypescript.Resource],
    authorizers: [Ash.Policy.Authorizer]

  typescript do
    type_name("SessionOccurrence")
  end

  postgres do
    table "session_occurrences"
    repo Improve.Repo
  end

  actions do
    defaults [:read]

    create :create_projected do
      primary? true

      accept [
        :plan_id,
        :session_template_id,
        :planned_for,
        :status,
        :recommendation_snapshot,
        :started_at,
        :notes
      ]

      validate {Improve.Validations.SamePlan,
                references: [
                  session_template_id: Improve.Plans.SessionTemplate
                ]}
    end

    update :start do
      accept [:started_at, :notes]
      change set_attribute(:status, :started)
    end

    update :complete do
      accept [:completed_at, :feedback, :notes]
      change set_attribute(:status, :completed)
    end

    update :mark_skipped do
      accept [:notes]
      change set_attribute(:status, :skipped)
    end

    update :mark_missed do
      accept [:notes]
      change set_attribute(:status, :missed)
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

    attribute :planned_for, :date do
      allow_nil? false
      public? true
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      default :planned

      constraints one_of: [
                    :planned,
                    :started,
                    :completed,
                    :missed,
                    :skipped,
                    :partially_completed
                  ]
    end

    attribute :recommendation_snapshot, :map do
      allow_nil? false
      public? true
      default %{}
    end

    attribute :started_at, :utc_datetime_usec do
      public? true
    end

    attribute :completed_at, :utc_datetime_usec do
      public? true
    end

    attribute :feedback, :map do
      allow_nil? false
      public? true
      default %{}
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

    belongs_to :session_template, Improve.Plans.SessionTemplate do
      allow_nil? false
      public? true
    end

    has_many :slot_results, Improve.Sessions.SlotResult
    has_many :event_instances, Improve.Journal.EventInstance
  end
end
