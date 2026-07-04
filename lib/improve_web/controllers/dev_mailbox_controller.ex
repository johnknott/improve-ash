defmodule ImproveWeb.DevMailboxController do
  use ImproveWeb, :controller

  alias Improve.Emails.LocalMailbox

  def latest_otp(conn, %{"email" => email}) do
    json(conn, %{message: LocalMailbox.latest_otp_for(email)})
  end

  def latest_otp(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(ImproveWeb.ApiError.payload("invalid_request", "email is required"))
  end
end
