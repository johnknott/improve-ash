defmodule ImproveWeb.AuthController do
  use ImproveWeb, :controller

  alias AshAuthentication.Plug.Helpers
  alias Improve.Accounts
  alias Improve.Accounts.Auth

  def request_code(conn, %{"email" => email}) do
    case Auth.request_login_code(email) do
      :ok ->
        json(conn, %{ok: true})

      {:error, error} ->
        if rate_limited?(error) do
          auth_error(conn, 429, "Please wait before trying again.")
        else
          auth_error(conn, 400, "We could not send a code right now.")
        end
    end
  end

  def request_code(conn, _params) do
    auth_error(conn, 400, "We could not send a code right now.")
  end

  def verify_code(conn, %{"email" => email, "otp" => otp}) do
    case Auth.verify_login_code(email, otp) do
      {:ok, user} ->
        conn
        |> Helpers.store_in_session(user)
        |> json(%{user: user_json(user)})

      {:error, error} ->
        if rate_limited?(error) do
          auth_error(conn, 429, "Please wait before trying again.")
        else
          auth_error(conn, 401, "That code was invalid or expired.")
        end
    end
  end

  def verify_code(conn, _params) do
    auth_error(conn, 400, "That code was invalid or expired.")
  end

  def me(conn, _params) do
    json(conn, %{user: user_json(conn.assigns[:current_user])})
  end

  def complete_profile(%{assigns: %{current_user: nil}} = conn, _params) do
    auth_error(conn, 401, "Please sign in to continue.")
  end

  def complete_profile(%{assigns: %{current_user: user}} = conn, %{"full_name" => full_name}) do
    case Accounts.complete_profile(user, %{full_name: String.trim(full_name)}, actor: user) do
      {:ok, user} ->
        json(conn, %{user: user_json(user)})

      {:error, _error} ->
        auth_error(conn, 422, "Please enter your name.")
    end
  end

  def complete_profile(conn, _params) do
    auth_error(conn, 422, "Please enter your name.")
  end

  def logout(conn, _params) do
    conn
    |> Helpers.revoke_session_tokens(:improve)
    |> configure_session(drop: true)
    |> json(%{ok: true})
  end

  defp auth_error(conn, status, message) do
    conn
    |> put_status(status)
    |> json(%{error: %{message: message}})
  end

  defp rate_limited?(%AshRateLimiter.LimitExceeded{}), do: true
  defp rate_limited?(%Ash.Error.Invalid{errors: errors}), do: Enum.any?(errors, &rate_limited?/1)

  defp rate_limited?(%Ash.Error.Forbidden{errors: errors}),
    do: Enum.any?(errors, &rate_limited?/1)

  defp rate_limited?(%Ash.Error.Unknown{errors: errors}), do: Enum.any?(errors, &rate_limited?/1)

  defp rate_limited?(%AshAuthentication.Errors.AuthenticationFailed{caused_by: error}),
    do: rate_limited?(error)

  defp rate_limited?(_error), do: false

  defp user_json(nil), do: nil

  defp user_json(user) do
    %{
      id: user.id,
      email: user.email,
      fullName: user.full_name
    }
  end
end
