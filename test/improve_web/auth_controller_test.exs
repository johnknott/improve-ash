defmodule ImproveWeb.AuthControllerTest do
  use ImproveWeb.ConnCase, async: false

  alias Improve.Accounts
  alias Improve.Emails.LocalMailbox
  alias Improve.Repo

  setup do
    LocalMailbox.clear()
    :ets.delete_all_objects(Improve.Hammer)
    :ok
  end

  test "new users can request a code, verify it, read current user, and log out", %{conn: conn} do
    email = "new-auth-user@example.test"

    conn = post(conn, ~p"/api/auth/request-code", %{email: email})
    assert json_response(conn, 200) == %{"ok" => true}

    code = latest_code!(email)

    conn = post(conn, ~p"/api/auth/verify-code", %{email: email, otp: code})
    assert %{"user" => %{"id" => user_id, "email" => ^email}} = json_response(conn, 200)

    conn = get(conn, ~p"/api/auth/me")
    assert %{"user" => %{"id" => ^user_id, "email" => ^email}} = json_response(conn, 200)

    conn = post(conn, ~p"/api/auth/logout", %{})
    assert json_response(conn, 200) == %{"ok" => true}

    conn = get(conn, ~p"/api/auth/me")
    assert json_response(conn, 200) == %{"user" => nil}
  end

  test "signing in again reuses the existing user", %{conn: conn} do
    email = "returning-auth-user@example.test"

    user_id =
      conn
      |> request_and_verify!(email)
      |> response_user_id()

    conn = post(conn, ~p"/api/auth/logout", %{})
    assert json_response(conn, 200) == %{"ok" => true}

    user_id_again =
      conn
      |> request_and_verify!(email)
      |> response_user_id()

    assert user_id_again == user_id
    assert Accounts.get_user_by_email!(email).id == user_id
  end

  test "signed-in users can complete their profile", %{conn: conn} do
    email = "profile-auth-user@example.test"

    conn = request_and_verify!(conn, email)

    assert %{"user" => %{"fullName" => nil}} = json_response(conn, 200)

    conn = post(conn, ~p"/api/auth/profile", %{full_name: "  John Knott  "})

    assert %{"user" => %{"email" => ^email, "fullName" => "John Knott"}} =
             json_response(conn, 200)

    assert Accounts.get_user_by_email!(email).full_name == "John Knott"
  end

  test "profile completion requires a signed-in user", %{conn: conn} do
    conn = post(conn, ~p"/api/auth/profile", %{full_name: "John Knott"})

    assert %{"error" => %{"message" => "Please sign in to continue."}} =
             json_response(conn, 401)
  end

  test "profile completion requires a name", %{conn: conn} do
    conn =
      conn
      |> request_and_verify!("blank-profile-auth-user@example.test")
      |> post(~p"/api/auth/profile", %{full_name: "   "})

    assert %{"error" => %{"message" => "Please enter your name."}} =
             json_response(conn, 422)
  end

  test "wrong codes return a generic failure and do not create an account", %{conn: conn} do
    email = "wrong-code@example.test"

    conn = post(conn, ~p"/api/auth/request-code", %{email: email})
    assert json_response(conn, 200) == %{"ok" => true}

    conn = post(conn, ~p"/api/auth/verify-code", %{email: email, otp: "000000"})

    assert %{"error" => %{"message" => "That code was invalid or expired."}} =
             json_response(conn, 401)

    assert_raise Ash.Error.Invalid, fn -> Accounts.get_user_by_email!(email) end
  end

  test "OTP codes are single-use", %{conn: conn} do
    email = "single-use@example.test"

    conn = post(conn, ~p"/api/auth/request-code", %{email: email})
    assert json_response(conn, 200) == %{"ok" => true}

    code = latest_code!(email)

    conn = post(conn, ~p"/api/auth/verify-code", %{email: email, otp: code})
    assert %{"user" => %{"email" => ^email}} = json_response(conn, 200)

    conn = post(conn, ~p"/api/auth/logout", %{})
    assert json_response(conn, 200) == %{"ok" => true}

    conn = post(conn, ~p"/api/auth/verify-code", %{email: email, otp: code})

    assert %{"error" => %{"message" => "That code was invalid or expired."}} =
             json_response(conn, 401)
  end

  test "expired OTP codes fail", %{conn: conn} do
    email = "expired-code@example.test"

    conn = post(conn, ~p"/api/auth/request-code", %{email: email})
    assert json_response(conn, 200) == %{"ok" => true}

    code = latest_code!(email)

    Repo.query!(
      "update tokens set expires_at = now() - interval '1 minute' where purpose = 'otp'"
    )

    conn = post(conn, ~p"/api/auth/verify-code", %{email: email, otp: code})

    assert %{"error" => %{"message" => "That code was invalid or expired."}} =
             json_response(conn, 401)
  end

  test "requesting too many codes is rate limited", %{conn: conn} do
    email = "request-rate-limit@example.test"

    Enum.each(1..5, fn _ ->
      conn = post(conn, ~p"/api/auth/request-code", %{email: email})
      assert json_response(conn, 200) == %{"ok" => true}
    end)

    conn = post(conn, ~p"/api/auth/request-code", %{email: email})

    assert %{"error" => %{"message" => "Please wait before trying again."}} =
             json_response(conn, 429)
  end

  test "too many wrong code attempts are rate limited", %{conn: conn} do
    email = "verify-rate-limit@example.test"

    conn = post(conn, ~p"/api/auth/request-code", %{email: email})
    assert json_response(conn, 200) == %{"ok" => true}

    Enum.each(1..5, fn _ ->
      conn = post(conn, ~p"/api/auth/verify-code", %{email: email, otp: "000000"})
      assert json_response(conn, 401)
    end)

    conn = post(conn, ~p"/api/auth/verify-code", %{email: email, otp: "000000"})

    assert %{"error" => %{"message" => "Please wait before trying again."}} =
             json_response(conn, 429)
  end

  defp request_and_verify!(conn, email) do
    conn = post(conn, ~p"/api/auth/request-code", %{email: email})
    assert json_response(conn, 200) == %{"ok" => true}

    post(conn, ~p"/api/auth/verify-code", %{email: email, otp: latest_code!(email)})
  end

  defp response_user_id(conn) do
    assert %{"user" => %{"id" => user_id}} = json_response(conn, 200)
    user_id
  end

  defp latest_code!(email) do
    email
    |> LocalMailbox.latest_otp_for()
    |> Map.fetch!(:code)
  end
end
