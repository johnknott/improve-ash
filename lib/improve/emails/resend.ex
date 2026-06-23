defmodule Improve.Emails.Resend do
  @endpoint "https://api.resend.com/emails"

  def deliver_otp(_email, _otp_code, email_message) do
    config = Application.fetch_env!(:improve, __MODULE__)

    payload = %{
      from: Keyword.fetch!(config, :from),
      to: email_message.to,
      subject: email_message.subject,
      text: email_message.text,
      html: email_message.html,
      tags: [
        %{name: "category", value: "otp"}
      ]
    }

    case Req.post(@endpoint,
           auth: {:bearer, Keyword.fetch!(config, :api_key)},
           json: payload
         ) do
      {:ok, %{status: status}} when status in 200..299 ->
        :ok

      {:ok, response} ->
        {:error, {:resend_error, response.status}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
