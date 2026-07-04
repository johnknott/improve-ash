defmodule Improve.Accounts.User do
  use Ash.Resource,
    otp_app: :improve,
    domain: Improve.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication, AshRateLimiter]

  postgres do
    table "users"
    repo Improve.Repo
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    policy action_type(:create) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if expr(id == ^actor(:id))
    end

    policy action_type([:update, :destroy]) do
      authorize_if expr(id == ^actor(:id))
    end
  end

  authentication do
    tokens do
      enabled?(true)
      store_all_tokens?(true)
      require_token_presence_for_authentication?(true)
      token_resource(Improve.Accounts.Token)
      signing_secret(Improve.Accounts.Secrets)
    end

    strategies do
      otp do
        identity_field(:email)
        registration_enabled?(true)
        brute_force_strategy(:rate_limit)
        sender(Improve.Accounts.OtpSender)
        otp_lifetime({10, :minutes})
        otp_length(6)
        otp_characters(:digits_only)
      end
    end
  end

  rate_limit do
    backend Improve.Hammer

    action :request_otp,
      limit: 5,
      per: :timer.minutes(15),
      key: &__MODULE__.otp_request_rate_limit_key/1

    action :sign_in_with_otp,
      limit: 5,
      per: :timer.minutes(10),
      key: &__MODULE__.otp_sign_in_rate_limit_key/1
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:email, :full_name]
    end

    update :update do
      primary? true
      accept [:email, :full_name]
    end

    update :complete_profile do
      accept [:full_name]

      validate present(:full_name) do
        message "is required"
      end
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :string do
      allow_nil? false
      public? true
      constraints match: ~r/^[^\s]+@[^\s]+$/
    end

    attribute :full_name, :string do
      allow_nil? true
      public? true
    end

    create_timestamp :inserted_at, public?: true
    update_timestamp :updated_at, public?: true
  end

  relationships do
    has_many :plans, Improve.Plans.Plan
  end

  identities do
    identity :unique_email, [:email]
  end

  def otp_request_rate_limit_key(input), do: otp_rate_limit_key(input, "request")
  def otp_sign_in_rate_limit_key(input), do: otp_rate_limit_key(input, "sign_in")

  defp otp_rate_limit_key(input, action) do
    email =
      input
      |> Ash.Subject.get_argument_or_attribute(:email, "unknown")
      |> to_string()
      |> String.downcase()

    "otp:#{action}:#{email}"
  end
end
