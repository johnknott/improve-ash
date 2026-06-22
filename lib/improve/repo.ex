defmodule Improve.Repo do
  use Ecto.Repo,
    otp_app: :improve,
    adapter: Ecto.Adapters.Postgres
end
