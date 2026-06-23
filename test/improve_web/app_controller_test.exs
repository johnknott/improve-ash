defmodule ImproveWeb.AppControllerTest do
  use ImproveWeb.ConnCase, async: false

  alias Improve.Accounts
  alias Improve.Emails.LocalMailbox
  alias Improve.Plans

  setup do
    LocalMailbox.clear()
    :ets.delete_all_objects(Improve.Hammer)
    :ok
  end

  test "signed-in users can install demo plans from the app API", %{conn: conn} do
    email = "app-demo-install@example.test"
    conn = sign_in!(conn, email)

    conn = post(conn, ~p"/api/app/demo-plans", %{kind: "gym"})

    assert %{
             "currentPlan" => %{
               "id" => gym_plan_id,
               "name" => "General Fitness",
               "sourceKey" => "gym"
             },
             "today" => %{"planId" => today_plan_id}
           } = json_response(conn, 200)

    assert today_plan_id == gym_plan_id

    conn = post(conn, ~p"/api/app/demo-plans", %{kind: "gym"})
    assert %{"currentPlan" => %{"id" => ^gym_plan_id}} = json_response(conn, 200)

    assert {:ok, plans} = Plans.list_plans(actor: Accounts.get_user_by_email!(email))
    assert Enum.count(plans, &(&1.source_key == "gym")) == 1
  end

  test "unknown demo plan names are rejected", %{conn: conn} do
    conn =
      conn
      |> sign_in!("unknown-demo-install@example.test")
      |> post(~p"/api/app/demo-plans", %{kind: "not-real"})

    assert %{"error" => %{"message" => "Choose a demo plan to install."}} =
             json_response(conn, 422)
  end

  defp sign_in!(conn, email) do
    conn = post(conn, ~p"/api/auth/request-code", %{email: email})
    assert json_response(conn, 200) == %{"ok" => true}

    post(conn, ~p"/api/auth/verify-code", %{
      email: email,
      otp: LocalMailbox.latest_otp_for(email).code
    })
  end
end
