defmodule Improve.Accounts.OtpSender do
  use AshAuthentication.Sender

  @impl true
  def send(user_or_email, otp_code, _opts) do
    user_or_email
    |> email_address()
    |> Improve.Emails.deliver_otp(otp_code)
  end

  defp email_address(%{email: email}), do: to_string(email)
  defp email_address(email) when is_binary(email), do: email
end
