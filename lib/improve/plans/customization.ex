defmodule Improve.Plans.Customization do
  @moduledoc """
  Durable record of a one-time plan customization run.

  Customization is Layer 2 of an adaptive plan: it derives values (for example
  training paces) from a baseline once, and writes the results into ordinary
  plan data (track guidance). This record captures what was derived, from which
  baseline, using which recipe, and where it was applied, so the origin of
  derived static structure is auditable and clearly separable from
  projection-time adaptation, which never writes.
  """

  use Ash.Resource,
    otp_app: :improve,
    domain: Improve.Plans,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "customizations"
    repo Improve.Repo
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:plan_id, :key, :kind, :baseline, :recipe, :outputs, :applied_changes]
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:key, :kind, :baseline, :recipe, :outputs, :applied_changes]
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
      constraints one_of: [:baseline, :other]
    end

    attribute :baseline, :map do
      allow_nil? false
      public? true
      default %{}
    end

    attribute :recipe, :map do
      allow_nil? false
      public? true
      default %{}
    end

    attribute :outputs, :map do
      allow_nil? false
      public? true
      default %{}
    end

    attribute :applied_changes, :map do
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
  end

  identities do
    identity :unique_key_per_plan, [:plan_id, :key]
  end
end
