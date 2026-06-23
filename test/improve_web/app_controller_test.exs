defmodule ImproveWeb.AppControllerTest do
  use ImproveWeb.ConnCase, async: false

  alias Improve.Accounts
  alias Improve.Emails.LocalMailbox
  alias Improve.Fixtures.GymPlan
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

  test "signed-in users can start, swap, log, and complete a projected gym session", %{conn: conn} do
    email = "app-session-flow@example.test"
    conn = sign_in!(conn, email)
    user = Accounts.get_user_by_email!(email)
    %{plan: plan} = GymPlan.install!(user, starts_on: ~D[2026-06-22])

    [template] = Plans.list_session_templates!(actor: user, query: [filter: [plan_id: plan.id]])

    conn =
      post(conn, ~p"/api/app/start-session", %{
        plan_id: plan.id,
        session_template_id: template.id,
        date: "2026-06-22"
      })

    assert %{
             "today" => %{
               "work" => [
                 %{
                   "status" => "started",
                   "session" => %{
                     "state" => %{"session_occurrence_id" => occurrence_id},
                     "slotResults" => slot_results
                   }
                 }
               ]
             }
           } = json_response(conn, 200)

    assert length(slot_results) == 5

    slot_result =
      Enum.find(slot_results, fn slot_result ->
        slot_result["slotKey"] == "push" and is_nil(slot_result["eventInstanceId"])
      end)

    swapped_item_key = alternate_push_item_key(slot_result["recommendedItemKey"])

    conn =
      post(conn, ~p"/api/app/swap-session-slot", %{
        slot_result_id: slot_result["id"],
        actual_item_key: swapped_item_key,
        date: "2026-06-22"
      })

    assert %{
             "today" => %{
               "work" => [
                 %{"session" => %{"slotResults" => swapped_slot_results}}
               ]
             }
           } = json_response(conn, 200)

    assert Enum.any?(
             swapped_slot_results,
             &(&1["id"] == slot_result["id"] and &1["status"] == "swapped" and
                 &1["actualItemKey"] == swapped_item_key)
           )

    conn =
      post(conn, ~p"/api/app/log-session-slot", %{
        session_occurrence_id: occurrence_id,
        slot_key: slot_result["slotKey"],
        actual_item_key: swapped_item_key,
        recommended_item_key: slot_result["recommendedItemKey"],
        event_key: "workout_exercise_performed",
        role: "exercise",
        date: "2026-06-22",
        payload: %{"sets" => 3, "reps" => 10, "load" => 45, "load_unit" => "kg"}
      })

    assert %{
             "today" => %{
               "work" => [
                 %{
                   "session" => %{
                     "slotResults" => updated_slot_results,
                     "state" => %{"slot_results_logged" => 1}
                   }
                 }
               ]
             }
           } = json_response(conn, 200)

    assert Enum.any?(
             updated_slot_results,
             &(&1["id"] == slot_result["id"] and &1["eventInstanceId"])
           )

    assert [
             %{
               "itemLinks" => [%{"itemKey" => ^swapped_item_key, "role" => "exercise"}],
               "slot" => %{"slotKey" => "push"}
             }
           ] = get_in(json_response(conn, 200), ["journal"])

    conn =
      post(conn, ~p"/api/app/complete-session", %{
        session_occurrence_id: occurrence_id,
        date: "2026-06-22"
      })

    assert %{
             "today" => %{
               "work" => [%{"status" => "completed"}]
             }
           } = json_response(conn, 200)
  end

  test "signed-in users can skip a started session", %{conn: conn} do
    email = "app-session-skip@example.test"
    conn = sign_in!(conn, email)
    user = Accounts.get_user_by_email!(email)
    %{plan: plan} = GymPlan.install!(user, starts_on: ~D[2026-06-22])

    [template] = Plans.list_session_templates!(actor: user, query: [filter: [plan_id: plan.id]])

    conn =
      post(conn, ~p"/api/app/start-session", %{
        plan_id: plan.id,
        session_template_id: template.id,
        date: "2026-06-24"
      })

    assert %{
             "today" => %{
               "work" => [
                 %{
                   "session" => %{"state" => %{"session_occurrence_id" => occurrence_id}}
                 }
               ]
             }
           } = json_response(conn, 200)

    conn =
      post(conn, ~p"/api/app/skip-session", %{
        session_occurrence_id: occurrence_id,
        date: "2026-06-24",
        note: "Travel"
      })

    assert %{
             "today" => %{
               "work" => [%{"status" => "skipped"}]
             }
           } = json_response(conn, 200)
  end

  defp alternate_push_item_key(recommended_key) do
    Enum.find(["chest_press", "shoulder_press", "cable_fly"], &(&1 != recommended_key))
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
