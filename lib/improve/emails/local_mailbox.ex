defmodule Improve.Emails.LocalMailbox do
  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  def deliver_otp(email, otp_code, email_message) do
    message = %{
      kind: :otp,
      to: email,
      code: otp_code,
      subject: email_message.subject,
      text: email_message.text,
      sent_at: DateTime.utc_now()
    }

    Agent.update(__MODULE__, &[message | &1])
    :ok
  end

  def all do
    Agent.get(__MODULE__, & &1)
  end

  def latest_otp_for(email) do
    Enum.find(all(), &(&1.kind == :otp and &1.to == email))
  end

  def clear do
    Agent.update(__MODULE__, fn _messages -> [] end)
  end
end
