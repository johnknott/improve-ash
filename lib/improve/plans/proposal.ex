defmodule Improve.Plans.Proposal do
  use Ash.Resource,
    otp_app: :improve,
    domain: Improve.Plans,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "proposals"
    repo Improve.Repo

    identity_wheres_to_sql(
      unique_divergence_per_plan: "status = 'proposed' AND divergence_key IS NOT NULL"
    )
  end

  actions do
    defaults [:read]

    create :propose do
      primary? true

      accept [
        :plan_id,
        :status,
        :source_evaluator,
        :proposed_edit,
        :evidence,
        :affected_fields,
        :text,
        :kind,
        :divergence_key
      ]
    end

    update :refresh do
      accept [:proposed_edit, :evidence, :text, :affected_fields]
      change set_attribute(:refreshed_at, &DateTime.utc_now/0)
    end

    update :approve do
      accept []

      validate data_one_of(:status, [:proposed]) do
        message "can only approve a proposed proposal"
      end

      change set_attribute(:status, :approved)
      change set_attribute(:decided_at, &DateTime.utc_now/0)
    end

    update :dismiss do
      accept [:dismiss_reason]

      validate data_one_of(:status, [:proposed]) do
        message "can only dismiss a proposed proposal"
      end

      change set_attribute(:status, :dismissed)
      change set_attribute(:decided_at, &DateTime.utc_now/0)
    end

    update :mark_applied do
      accept []

      validate data_one_of(:status, [:approved]) do
        message "can only apply an approved proposal"
      end

      change set_attribute(:status, :applied)
      change set_attribute(:applied_at, &DateTime.utc_now/0)
    end

    update :expire do
      accept []

      validate data_one_of(:status, [:proposed]) do
        message "can only expire a proposed proposal"
      end

      change set_attribute(:status, :expired)
      change set_attribute(:decided_at, &DateTime.utc_now/0)
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
      default :proposed
      constraints one_of: [:proposed, :approved, :dismissed, :applied, :expired]
    end

    attribute :kind, :string do
      allow_nil? false
      public? true
    end

    attribute :source_evaluator, :string do
      public? true
    end

    attribute :proposed_edit, :map do
      allow_nil? false
      public? true
    end

    attribute :evidence, :map do
      public? true
      default %{}
    end

    attribute :affected_fields, {:array, :string} do
      public? true
      default []
    end

    attribute :text, :string do
      allow_nil? false
      public? true
    end

    attribute :divergence_key, :string do
      public? true
    end

    attribute :dismiss_reason, :string do
      public? true
    end

    attribute :decided_at, :utc_datetime_usec do
      public? true
    end

    attribute :applied_at, :utc_datetime_usec do
      public? true
    end

    attribute :refreshed_at, :utc_datetime_usec do
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

  identities do
    identity :unique_divergence_per_plan, [:plan_id, :divergence_key],
      where: expr(status == :proposed and not is_nil(divergence_key))
  end
end
