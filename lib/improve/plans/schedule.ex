defmodule Improve.Plans.Schedule do
  use Ash.Resource,
    otp_app: :improve,
    domain: Improve.Plans,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "schedules"
    repo Improve.Repo
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:plan_id, :owner_type, :owner_id, :kind, :rules, :starts_on, :ends_on]

      validate {Improve.Validations.SamePlan,
                polymorphic_reference: [
                  type_field: :owner_type,
                  id_field: :owner_id,
                  resources: %{
                    session_template: Improve.Plans.SessionTemplate,
                    track: Improve.Plans.Track
                  }
                ]}
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:owner_type, :owner_id, :kind, :rules, :starts_on, :ends_on]

      validate {Improve.Validations.SamePlan,
                polymorphic_reference: [
                  type_field: :owner_type,
                  id_field: :owner_id,
                  resources: %{
                    session_template: Improve.Plans.SessionTemplate,
                    track: Improve.Plans.Track
                  }
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

    attribute :owner_type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:session_template, :track]
    end

    attribute :owner_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :kind, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :every_day,
                    :selected_weekdays,
                    :every_n_days,
                    :times_per_week,
                    :every_n_weeks,
                    :monthly,
                    :after_completion,
                    :custom
                  ]
    end

    attribute :rules, :map do
      allow_nil? false
      public? true
      default %{}
    end

    attribute :starts_on, :date do
      allow_nil? false
      public? true
    end

    attribute :ends_on, :date do
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
  end
end
