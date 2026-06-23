defmodule Improve.Accounts.Auth do
  alias AshAuthentication.{Info, Strategy}
  alias Improve.Accounts.User

  def request_login_code(email) when is_binary(email) do
    :otp
    |> strategy!()
    |> Strategy.action(:request, %{"email" => normalize_email(email)})
  end

  def verify_login_code(email, otp) when is_binary(email) and is_binary(otp) do
    :otp
    |> strategy!()
    |> Strategy.action(:sign_in, %{
      "email" => normalize_email(email),
      "otp" => String.trim(otp)
    })
  end

  defp strategy!(name), do: Info.strategy!(User, name)

  defp normalize_email(email) do
    email
    |> String.trim()
    |> String.downcase()
  end
end
