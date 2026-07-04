defmodule ImproveWeb.BearerTokenTest do
  use ImproveWeb.ConnCase, async: false

  alias Improve.Emails.LocalMailbox

  setup do
    LocalMailbox.clear()
    :ets.delete_all_objects(Improve.Hammer)
    :ok
  end

  test "verify-code returns a bearer token", %{conn: conn} do
    conn = sign_in!(conn, "bearer-user@example.test")
    body = json_response(conn, 200)

    assert is_binary(body["token"])
    assert String.length(body["token"]) > 50
  end

  test "bearer token authenticates requests without a session", %{conn: conn} do
    token = sign_in_and_get_token!(conn, "bearer-auth@example.test")

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{token}")
      |> get(~p"/api/auth/me")

    assert %{"user" => %{"email" => "bearer-auth@example.test"}} = json_response(conn, 200)
  end

  test "invalid bearer token does not authenticate", %{conn: _conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer invalid.token.here")
      |> get(~p"/api/auth/me")

    assert %{"user" => nil} = json_response(conn, 200)
  end

  test "refresh-token issues a new valid token", %{conn: conn} do
    token = sign_in_and_get_token!(conn, "refresh-user@example.test")

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{token}")
      |> post(~p"/api/auth/refresh-token")

    assert %{"token" => new_token} = json_response(conn, 200)
    assert is_binary(new_token)
    assert new_token != token

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{new_token}")
      |> get(~p"/api/auth/me")

    assert %{"user" => %{"email" => "refresh-user@example.test"}} = json_response(conn, 200)
  end

  test "refresh-token requires authentication", %{conn: _conn} do
    conn = post(build_conn(), ~p"/api/auth/refresh-token")
    assert %{"error" => _} = json_response(conn, 401)
  end

  test "revoke-token invalidates the bearer token", %{conn: conn} do
    token = sign_in_and_get_token!(conn, "revoke-user@example.test")

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{token}")
      |> post(~p"/api/auth/revoke-token")

    assert %{"ok" => true} = json_response(conn, 200)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{token}")
      |> get(~p"/api/auth/me")

    assert %{"user" => nil} = json_response(conn, 200)
  end

  test "logout also revokes the bearer token", %{conn: conn} do
    token = sign_in_and_get_token!(conn, "logout-bearer@example.test")

    build_conn()
    |> put_req_header("authorization", "Bearer #{token}")
    |> post(~p"/api/auth/logout")

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{token}")
      |> get(~p"/api/auth/me")

    assert %{"user" => nil} = json_response(conn, 200)
  end

  test "session auth still works alongside bearer", %{conn: conn} do
    conn = sign_in!(conn, "session-still-works@example.test")

    conn = get(conn, ~p"/api/auth/me")
    assert %{"user" => %{"email" => "session-still-works@example.test"}} = json_response(conn, 200)
  end

  defp sign_in!(conn, email) do
    post(conn, ~p"/api/auth/request-code", %{email: email})
    code = LocalMailbox.latest_otp_for(email) |> Map.fetch!(:code)
    post(conn, ~p"/api/auth/verify-code", %{email: email, otp: code})
  end

  defp sign_in_and_get_token!(conn, email) do
    conn = sign_in!(conn, email)
    json_response(conn, 200) |> Map.fetch!("token")
  end
end
