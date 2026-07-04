defmodule ImproveWeb.AuthoringApiTest do
  use ImproveWeb.ConnCase, async: false

  alias Improve.Emails.LocalMailbox
  alias Improve.{Accounts, Plans}

  setup do
    LocalMailbox.clear()
    :ets.delete_all_objects(Improve.Hammer)
    :ok
  end

  describe "session template CRUD" do
    test "create and update a session template", %{conn: conn} do
      {conn, plan_id} = setup_plan(conn, "session-tpl@example.test")

      conn =
        post(conn, ~p"/api/app/session-templates", %{
          plan_id: plan_id,
          key: "morning_workout",
          name: "Morning Workout",
          description: "A quick AM session"
        })

      assert %{"planDetail" => %{"sessionTemplates" => [template]}} = json_response(conn, 200)
      assert template["key"] == "morning_workout"
      assert template["name"] == "Morning Workout"

      conn =
        patch(conn, ~p"/api/app/session-templates/#{template["id"]}", %{
          plan_id: plan_id,
          name: "Updated Workout"
        })

      assert %{"planDetail" => %{"sessionTemplates" => [updated]}} = json_response(conn, 200)
      assert updated["name"] == "Updated Workout"
      assert updated["key"] == "morning_workout"
    end

    test "session template requires a name", %{conn: conn} do
      {conn, plan_id} = setup_plan(conn, "session-tpl-val@example.test")

      conn =
        post(conn, ~p"/api/app/session-templates", %{
          plan_id: plan_id,
          key: "empty",
          name: ""
        })

      assert %{"error" => %{"details" => [%{"field" => "name"}]}} = json_response(conn, 422)
    end
  end

  describe "session slot CRUD" do
    test "create and update a session slot", %{conn: conn} do
      {conn, plan_id} = setup_plan(conn, "session-slot@example.test")

      conn =
        post(conn, ~p"/api/app/session-templates", %{
          plan_id: plan_id,
          key: "gym",
          name: "Gym Session"
        })

      template_id = get_in(json_response(conn, 200), ["planDetail", "sessionTemplates", Access.at(0), "id"])

      pool_id = create_pool!(plan_id)

      conn =
        post(conn, ~p"/api/app/session-slots", %{
          plan_id: plan_id,
          session_template_id: template_id,
          pool_id: pool_id,
          key: "push",
          name: "Push exercise",
          count: 2,
          position: 1
        })

      assert %{"planDetail" => %{"sessionSlots" => [slot]}} = json_response(conn, 200)
      assert slot["key"] == "push"
      assert slot["count"] == 2

      conn =
        patch(conn, ~p"/api/app/session-slots/#{slot["id"]}", %{
          plan_id: plan_id,
          name: "Push movement",
          count: 3
        })

      assert %{"planDetail" => %{"sessionSlots" => [updated]}} = json_response(conn, 200)
      assert updated["name"] == "Push movement"
      assert updated["count"] == 3
    end
  end

  describe "item CRUD" do
    test "create and update an item", %{conn: conn} do
      {conn, plan_id} = setup_plan(conn, "item-crud@example.test")

      conn =
        post(conn, ~p"/api/app/item-types", %{
          plan_id: plan_id,
          key: "exercise",
          name: "Exercise"
        })

      item_type_id = get_in(json_response(conn, 200), ["planDetail", "itemTypes", Access.at(0), "id"])

      conn =
        post(conn, ~p"/api/app/items", %{
          plan_id: plan_id,
          item_type_id: item_type_id,
          key: "bench_press",
          name: "Bench Press"
        })

      assert %{"planDetail" => %{"items" => [item]}} = json_response(conn, 200)
      assert item["key"] == "bench_press"
      assert item["name"] == "Bench Press"

      conn =
        patch(conn, ~p"/api/app/items/#{item["id"]}", %{
          plan_id: plan_id,
          name: "Barbell Bench Press"
        })

      assert %{"planDetail" => %{"items" => [updated]}} = json_response(conn, 200)
      assert updated["name"] == "Barbell Bench Press"
    end

    test "item requires a name", %{conn: conn} do
      {conn, plan_id} = setup_plan(conn, "item-val@example.test")

      conn = post(conn, ~p"/api/app/items", %{plan_id: plan_id, key: "x", name: ""})

      assert %{"error" => %{"details" => [%{"field" => "name"}]}} = json_response(conn, 422)
    end
  end

  describe "item type CRUD" do
    test "create and update an item type", %{conn: conn} do
      {conn, plan_id} = setup_plan(conn, "item-type@example.test")

      conn =
        post(conn, ~p"/api/app/item-types", %{
          plan_id: plan_id,
          key: "exercise",
          name: "Exercise",
          description: "Gym exercises"
        })

      assert %{"planDetail" => %{"itemTypes" => [item_type]}} = json_response(conn, 200)
      assert item_type["key"] == "exercise"

      conn =
        patch(conn, ~p"/api/app/item-types/#{item_type["id"]}", %{
          plan_id: plan_id,
          name: "Resistance Exercise",
          description: "Weighted gym movements"
        })

      assert %{"planDetail" => %{"itemTypes" => [updated]}} = json_response(conn, 200)
      assert updated["name"] == "Resistance Exercise"
      assert updated["description"] == "Weighted gym movements"
    end
  end

  describe "event type CRUD" do
    test "create and update an event type", %{conn: conn} do
      {conn, plan_id} = setup_plan(conn, "event-type@example.test")

      conn =
        post(conn, ~p"/api/app/event-types", %{
          plan_id: plan_id,
          key: "run",
          name: "Run",
          payload_schema: %{required: ["distance", "unit"]}
        })

      assert %{"planDetail" => %{"eventTypes" => [et]}} = json_response(conn, 200)
      assert et["key"] == "run"
      assert et["payloadSchema"] == %{"required" => ["distance", "unit"]}

      conn =
        patch(conn, ~p"/api/app/event-types/#{et["id"]}", %{
          plan_id: plan_id,
          name: "Running",
          description: "Logged a run"
        })

      assert %{"planDetail" => %{"eventTypes" => [updated]}} = json_response(conn, 200)
      assert updated["name"] == "Running"
      assert updated["description"] == "Logged a run"
    end
  end

  describe "track edit" do
    test "update a track's name and target", %{conn: conn} do
      conn = sign_in!(conn, "track-edit@example.test")

      conn =
        post(conn, ~p"/api/app/plans", %{
          name: "Running",
          intention: "Run daily",
          starts_on: "2026-06-23",
          ends_on: "2026-08-19",
          date: "2026-06-23"
        })

      plan_id = get_in(json_response(conn, 200), ["currentPlan", "id"])

      conn =
        post(conn, ~p"/api/app/tracks", %{
          plan_id: plan_id,
          name: "Daily run",
          event_name: "Run",
          quantity: "5",
          unit: "km",
          date: "2026-06-23"
        })

      track = get_in(json_response(conn, 200), ["planDetail", "tracks", Access.at(0)])

      conn =
        patch(conn, ~p"/api/app/tracks/#{track["id"]}", %{
          plan_id: plan_id,
          name: "Morning run",
          target: %{mode: "fixed", quantity: "10", unit: "km"},
          date: "2026-06-23"
        })

      assert %{"planDetail" => %{"tracks" => [updated]}} = json_response(conn, 200)
      assert updated["name"] == "Morning run"
      assert updated["target"]["quantity"] == "10"
    end
  end

  describe "cross-user isolation" do
    test "cannot update resources in another user's plan", %{conn: conn} do
      {conn, plan_id} = setup_plan(conn, "authoring-owner@example.test")

      conn =
        post(conn, ~p"/api/app/event-types", %{
          plan_id: plan_id,
          key: "private_event",
          name: "Private Event"
        })

      et_id = get_in(json_response(conn, 200), ["planDetail", "eventTypes", Access.at(0), "id"])

      other_conn = sign_in!(build_conn(), "authoring-intruder@example.test")

      other_conn =
        patch(other_conn, ~p"/api/app/event-types/#{et_id}", %{
          plan_id: plan_id,
          name: "Hacked"
        })

      assert %{"error" => _} = json_response(other_conn, 404)
    end
  end

  defp create_pool!(plan_id) do
    actor = Accounts.get_user_by_email!("session-slot@example.test", authorize?: false)
    pool = Plans.create_pool!(%{plan_id: plan_id, key: "test_pool", name: "Test Pool"}, actor: actor)
    pool.id
  end

  defp setup_plan(conn, email) do
    conn = sign_in!(conn, email)

    conn =
      post(conn, ~p"/api/app/plans", %{
        name: "Test Plan",
        intention: "Testing authoring APIs",
        starts_on: "2026-06-23",
        ends_on: "2026-08-19",
        date: "2026-06-23"
      })

    plan_id = get_in(json_response(conn, 200), ["currentPlan", "id"])
    {conn, plan_id}
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
