defmodule Improve.Emails do
  def deliver_otp(email, otp_code) do
    adapter().deliver_otp(email, otp_code, otp_email(email, otp_code))
  end

  defp adapter do
    :improve
    |> Application.get_env(__MODULE__, [])
    |> Keyword.fetch!(:adapter)
  end

  defp otp_email(email, otp_code) do
    %{
      to: email,
      subject: "Your Improve code",
      text: """
      Your Improve code is #{otp_code}.

      This code expires in 10 minutes.

      If you did not request this, you can ignore this email.
      """,
      html: """
      <p>Your Improve code is <strong>#{otp_code}</strong>.</p>
      <p>This code expires in 10 minutes.</p>
      <p>If you did not request this, you can ignore this email.</p>
      """
    }
  end
end
