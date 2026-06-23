defmodule Improve.Emails do
  def deliver_otp(email, otp_code) do
    adapter().deliver_otp(email, otp_code)
  end

  defp adapter do
    :improve
    |> Application.get_env(__MODULE__, [])
    |> Keyword.fetch!(:adapter)
  end
end
