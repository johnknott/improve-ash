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
          auth_error(conn, 429, "rate_limited", "Please wait before trying again.")
        else
          auth_error(conn, 400, "invalid_request", "We could not send a code right now.")
        end
    end
  end

  def request_code(conn, _params) do
    auth_error(conn, 400, "invalid_request", "We could not send a code right now.")
  end

  def verify_code(conn, %{"email" => email, "otp" => otp}) do
    case Auth.verify_login_code(email, otp) do
      {:ok, user} ->
        conn
        |> Helpers.store_in_session(user)
        |> json(%{user: user_json(user), token: user.__metadata__.token})

      {:error, error} ->
        if rate_limited?(error) do
          auth_error(conn, 429, "rate_limited", "Please wait before trying again.")
        else
          auth_error(conn, 401, "invalid_credentials", "That code was invalid or expired.")
        end
    end
  end

  def verify_code(conn, _params) do
    auth_error(conn, 400, "invalid_request", "That code was invalid or expired.")
  end

  def me(conn, _params) do
    json(conn, %{user: user_json(conn.assigns[:current_user])})
  end

  def complete_profile(%{assigns: %{current_user: nil}} = conn, _params) do
    auth_error(conn, 401, "unauthenticated", "Please sign in to continue.")
  end

  def complete_profile(
        %{assigns: %{current_user: user}} = conn,
        %{"full_name" => full_name} = params
      ) do
    attrs =
      case Map.get(params, "timezone") do
        timezone when is_binary(timezone) and timezone != "" ->
          %{full_name: String.trim(full_name), timezone: timezone}

        _missing ->
          %{full_name: String.trim(full_name)}
      end

    case Accounts.complete_profile(user, attrs, actor: user) do
      {:ok, user} ->
        json(conn, %{user: user_json(user)})

      {:error, error} ->
        auth_error(conn, 422, "validation_failed", profile_error_message(error))
    end
  end

  def complete_profile(conn, _params) do
    auth_error(conn, 422, "validation_failed", "Please enter your name.")
  end

  def logout(conn, _params) do
    conn
    |> Helpers.revoke_bearer_tokens(:improve)
    |> Helpers.revoke_session_tokens(:improve)
    |> configure_session(drop: true)
    |> json(%{ok: true})
  end

  def refresh_token(%{assigns: %{current_user: nil}} = conn, _params) do
    auth_error(conn, 401, "unauthenticated", "Please sign in to continue.")
  end

  def refresh_token(%{assigns: %{current_user: user}} = conn, _params) do
    case AshAuthentication.Jwt.token_for_user(user) do
      {:ok, new_token, _claims} ->
        json(conn, %{token: new_token})

      {:error, _reason} ->
        auth_error(conn, 500, "token_error", "Could not issue a new token.")
    end
  end

  def revoke_token(conn, _params) do
    conn
    |> Helpers.revoke_bearer_tokens(:improve)
    |> json(%{ok: true})
  end

  defp auth_error(conn, status, code, message) do
    conn
    |> put_status(status)
    |> json(ImproveWeb.ApiError.payload(code, message))
  end

  defp rate_limited?(%AshRateLimiter.LimitExceeded{}), do: true
  defp rate_limited?(%Ash.Error.Invalid{errors: errors}), do: Enum.any?(errors, &rate_limited?/1)

  defp rate_limited?(%Ash.Error.Forbidden{errors: errors}),
    do: Enum.any?(errors, &rate_limited?/1)

  defp rate_limited?(%Ash.Error.Unknown{errors: errors}), do: Enum.any?(errors, &rate_limited?/1)

  defp rate_limited?(%AshAuthentication.Errors.AuthenticationFailed{caused_by: error}),
    do: rate_limited?(error)

  defp rate_limited?(_error), do: false

  defp profile_error_message(%Ash.Error.Invalid{errors: errors}) do
    if Enum.any?(errors, &(Map.get(&1, :field) == :timezone)) do
      "Please choose a valid time zone."
    else
      "Please enter your name."
    end
  end

  defp profile_error_message(_error), do: "Please enter your name."

  defp user_json(nil), do: nil

  defp user_json(user) do
    %{
      id: user.id,
      email: user.email,
      fullName: user.full_name,
      timezone: user.timezone
    }
  end
end
