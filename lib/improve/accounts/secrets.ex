defmodule Improve.Accounts.Secrets do
  use AshAuthentication.Secret

  @impl true
  def secret_for([:authentication, :tokens, :signing_secret], _resource, _opts, _context) do
    :improve
    |> Application.fetch_env!(ImproveWeb.Endpoint)
    |> Keyword.fetch!(:secret_key_base)
    |> then(&{:ok, &1})
  end

  def secret_for(_secret_name, _resource, _opts, _context), do: :error
end
