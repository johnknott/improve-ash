defmodule Improve.Accounts.Token do
  use Ash.Resource,
    otp_app: :improve,
    domain: Improve.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource]

  postgres do
    table "tokens"
    repo Improve.Repo
  end

  actions do
    defaults [:read]
  end
end
