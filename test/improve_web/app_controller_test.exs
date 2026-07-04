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

    assert {:ok, plans} =
             Plans.list_plans(actor: Accounts.get_user_by_email!(email, authorize?: false))

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

  test "app API requests require a signed-in user", %{conn: conn} do
    conn = get(conn, ~p"/api/app/dashboard")

    assert %{"error" => %{"message" => "Please sign in to continue."}} =
             json_response(conn, 401)
  end

  test "malformed plan creation payloads return validation errors", %{conn: conn} do
    conn =
      conn
      |> sign_in!("app-plan-create-invalid@example.test")
      |> post(~p"/api/app/plans", %{
        name: "",
        intention: "",
        starts_on: "2026-08-19",
        ends_on: "2026-06-23"
      })

    assert %{
             "error" => %{
               "code" => "validation_failed",
               "message" =>
                 "Plan name is required. Plan intention is required. Plan end date must be after the start date.",
               "details" => [
                 %{"field" => "name", "message" => "Plan name is required."},
                 %{"field" => "intention", "message" => "Plan intention is required."},
                 %{
                   "field" => "ends_on",
                   "message" => "Plan end date must be after the start date."
                 }
               ]
             }
           } = json_response(conn, 422)
  end

  test "signed-in users can create an empty plan from the app API", %{conn: conn} do
    conn =
      conn
      |> sign_in!("app-plan-create@example.test")
      |> post(~p"/api/app/plans", %{
        name: "Reading",
        intention: "Read a little every day",
        starts_on: "2026-06-23",
        ends_on: "2026-08-19",
        date: "2026-06-23"
      })

    response = json_response(conn, 200)

    assert %{
             "id" => plan_id,
             "name" => "Reading",
             "intention" => "Read a little every day",
             "status" => "draft"
           } = response["currentPlan"]

    assert [%{"id" => ^plan_id}] = response["plans"]
    assert %{"date" => "2026-06-23", "work" => []} = response["today"]
    assert %{"items" => [], "eventTypes" => []} = response["planDetail"]
  end

  test "signed-in users can update their plan container from the app API", %{conn: conn} do
    conn =
      conn
      |> sign_in!("app-plan-update@example.test")
      |> post(~p"/api/app/plans", %{
        name: "Reading",
        intention: "Read a little every day",
        starts_on: "2026-06-23",
        ends_on: "2026-08-19",
        date: "2026-06-23"
      })

    plan_id = get_in(json_response(conn, 200), ["currentPlan", "id"])

    conn =
      patch(conn, ~p"/api/app/plans/#{plan_id}", %{
        name: "Summer strength block",
        intention: "Build a consistent gym rhythm",
        starts_on: "2026-06-25",
        ends_on: "2026-08-19",
        date: "2026-06-25"
      })

    assert %{
             "currentPlan" => %{
               "id" => ^plan_id,
               "name" => "Summer strength block",
               "intention" => "Build a consistent gym rhythm",
               "startsOn" => "2026-06-25",
               "endsOn" => "2026-08-19",
               "dayLabel" => "Day 1 of 56"
             },
             "today" => %{"date" => "2026-06-25", "planId" => ^plan_id}
           } = json_response(conn, 200)
  end

  test "signed-in users can create a daily track from the app API", %{conn: conn} do
    conn = sign_in!(conn, "app-track-create@example.test")

    conn =
      post(conn, ~p"/api/app/plans", %{
        name: "Reading",
        intention: "Read a little every day",
        starts_on: "2026-06-23",
        ends_on: "2026-08-19",
        date: "2026-06-23"
      })

    plan_id = get_in(json_response(conn, 200), ["currentPlan", "id"])

    conn =
      post(conn, ~p"/api/app/tracks", %{
        plan_id: plan_id,
        name: "Read for 15 minutes",
        event_name: "Read",
        quantity: "15",
        unit: "minutes",
        date: "2026-06-23"
      })

    response = json_response(conn, 200)

    assert [
             %{
               "name" => "Read for 15 minutes",
               "eventTypeName" => "Read",
               "target" => %{"quantity" => "15", "unit" => "minutes"},
               "schedule" => %{"kind" => "every_day"}
             }
           ] = get_in(response, ["planDetail", "tracks"])

    assert [
             %{
               "title" => "Read for 15 minutes",
               "target" => %{"quantity" => "15", "unit" => "minutes"},
               "targetProgress" => %{
                 "completedEventCount" => 0,
                 "completedEventIds" => []
               },
               "canLog" => true
             }
           ] = get_in(response, ["today", "work"])
  end

  test "users cannot create tracks in another user's plan", %{conn: conn} do
    owner = Accounts.create_user!(%{email: "app-track-owner@example.test", full_name: "Owner"})

    plan =
      Plans.create_plan!(
        %{
          name: "Owner Plan",
          intention: "Private work",
          starts_on: ~D[2026-06-23],
          ends_on: ~D[2026-08-19]
        },
        actor: owner
      )

    conn =
      conn
      |> sign_in!("app-track-other-user@example.test")
      |> post(~p"/api/app/tracks", %{
        plan_id: plan.id,
        name: "Read",
        event_name: "Read",
        quantity: "15",
        unit: "minutes",
        date: "2026-06-23"
      })

    assert %{"error" => %{"message" => "That plan is not available."}} =
             json_response(conn, 404)
  end

  test "malformed track creation payloads return validation errors", %{conn: conn} do
    conn = sign_in!(conn, "app-track-create-invalid@example.test")

    conn =
      post(conn, ~p"/api/app/plans", %{
        name: "Reading",
        intention: "Read a little every day",
        starts_on: "2026-06-23",
        ends_on: "2026-08-19",
        date: "2026-06-23"
      })

    plan_id = get_in(json_response(conn, 200), ["currentPlan", "id"])

    conn =
      post(conn, ~p"/api/app/tracks", %{
        plan_id: plan_id,
        name: "",
        target_mode: "fixed",
        quantity: "",
        unit: "",
        event_name: "",
        date: "2026-06-23"
      })

    assert %{
             "error" => %{
               "message" =>
                 "Track name is required. Track amount is required. Track unit is required. Choose what this track logs."
             }
           } = json_response(conn, 422)
  end

  test "signed-in users can create a daily metric track from the app API", %{conn: conn} do
    conn = sign_in!(conn, "app-metric-track-create@example.test")

    conn =
      post(conn, ~p"/api/app/plans", %{
        name: "Body metrics",
        intention: "Notice trends without daily noise",
        starts_on: "2026-06-23",
        ends_on: "2026-08-19",
        date: "2026-06-23"
      })

    plan_id = get_in(json_response(conn, 200), ["currentPlan", "id"])

    conn =
      post(conn, ~p"/api/app/tracks", %{
        plan_id: plan_id,
        name: "Weigh myself",
        description: "Daily bodyweight check-in.",
        target_mode: "metric",
        metric_name: "Weight",
        event_name: "Weight",
        unit: "kg",
        date: "2026-06-23"
      })

    response = json_response(conn, 200)

    assert [
             %{
               "name" => "Weigh myself",
               "description" => "Daily bodyweight check-in.",
               "eventTypeName" => "Weight",
               "target" => %{
                 "mode" => "metric",
                 "metricName" => "Weight",
                 "quantity" => nil,
                 "unit" => "kg"
               },
               "schedule" => %{"kind" => "every_day"}
             }
           ] = get_in(response, ["planDetail", "tracks"])

    assert [
             %{
               "title" => "Weigh myself",
               "target" => %{
                 "mode" => "metric",
                 "metricName" => "Weight",
                 "quantity" => nil,
                 "unit" => "kg"
               },
               "targetProgress" => %{
                 "completedEventCount" => 0,
                 "completedEventIds" => [],
                 "recordedValue" => nil,
                 "unit" => "kg"
               },
               "canLog" => true
             }
           ] = get_in(response, ["today", "work"])
  end

  test "signed-in users can start, swap, log, and complete a projected gym session", %{conn: conn} do
    email = "app-session-flow@example.test"
    conn = sign_in!(conn, email)
    user = Accounts.get_user_by_email!(email, authorize?: false)
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
                     "state" => %{"sessionOccurrenceId" => occurrence_id},
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

    log_slot_params = %{
      session_occurrence_id: occurrence_id,
      slot_key: slot_result["slotKey"],
      actual_item_key: swapped_item_key,
      recommended_item_key: slot_result["recommendedItemKey"],
      event_key: "workout_exercise_performed",
      role: "exercise",
      date: "2026-06-22",
      payload: %{"sets" => 3, "reps" => 10, "load" => 45, "load_unit" => "kg"},
      client_device_id: "test-device",
      client_operation_id: "slot-log-op-1"
    }

    conn = post(conn, ~p"/api/app/log-session-slot", log_slot_params)

    assert %{
             "today" => %{
               "work" => [
                 %{
                   "session" => %{
                     "slotResults" => updated_slot_results,
                     "state" => %{"slotResultsLogged" => 1}
                   }
                 }
               ]
             }
           } = json_response(conn, 200)

    # A retried submission with the same operation id must not double-log.
    conn = post(conn, ~p"/api/app/log-session-slot", log_slot_params)

    assert %{
             "today" => %{
               "work" => [
                 %{"session" => %{"state" => %{"slotResultsLogged" => 1}}}
               ]
             }
           } = json_response(conn, 200)

    assert [_only_journal_event] = get_in(json_response(conn, 200), ["journal"])

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

  test "mutation responses carry only the slices they invalidate", %{conn: conn} do
    email = "app-slim-responses@example.test"
    conn = sign_in!(conn, email)
    user = Accounts.get_user_by_email!(email, authorize?: false)
    %{plan: plan} = GymPlan.install!(user, starts_on: ~D[2026-06-22])

    [template] = Plans.list_session_templates!(actor: user, query: [filter: [plan_id: plan.id]])

    conn =
      patch(conn, ~p"/api/app/plans/#{plan.id}", %{
        name: "Renamed plan",
        intention: "Same work, new name",
        starts_on: "2026-06-22",
        ends_on: "2026-08-19",
        date: "2026-06-22"
      })

    plan_update = json_response(conn, 200)
    assert Map.has_key?(plan_update, "plans")
    assert Map.has_key?(plan_update, "currentPlan")
    assert Map.has_key?(plan_update, "planDetail")
    refute Map.has_key?(plan_update, "journal")

    conn =
      post(conn, ~p"/api/app/start-session", %{
        plan_id: plan.id,
        session_template_id: template.id,
        date: "2026-06-22"
      })

    session_start = json_response(conn, 200)
    assert Map.has_key?(session_start, "today")
    assert Map.has_key?(session_start, "journal")
    refute Map.has_key?(session_start, "plans")
    refute Map.has_key?(session_start, "planDetail")

    conn = get(conn, ~p"/api/app/dashboard?date=2026-06-22")
    dashboard = json_response(conn, 200)

    for slice <- ["plans", "currentPlan", "today", "journal", "planDetail"] do
      assert Map.has_key?(dashboard, slice), "dashboard should include #{slice}"
    end
  end

  test "retried event logs with idempotency metadata do not duplicate", %{conn: conn} do
    email = "app-idempotent-log@example.test"
    conn = sign_in!(conn, email)
    user = Accounts.get_user_by_email!(email, authorize?: false)

    plan =
      Plans.create_plan!(
        %{
          name: "Idempotency plan",
          intention: "Prove retries are safe",
          starts_on: ~D[2026-06-22],
          ends_on: ~D[2026-07-20]
        },
        actor: user
      )

    event_type =
      Plans.create_event_type!(
        %{plan_id: plan.id, key: "water_break", name: "Water break"},
        actor: user
      )

    log_params = %{
      plan_id: plan.id,
      event_type_id: event_type.id,
      summary: "Drank water",
      quantity: "1",
      unit: "glass",
      client_device_id: "phone-1",
      client_operation_id: "op-123"
    }

    conn = post(conn, ~p"/api/app/log-event", log_params)
    assert %{"event" => %{"id" => event_id}} = json_response(conn, 200)

    conn = post(conn, ~p"/api/app/log-event", log_params)
    assert %{"event" => %{"id" => ^event_id}} = json_response(conn, 200)

    assert [_only_event] = Improve.Journal.read_journal!(plan, actor: user)
  end

  test "offline event batches return per-entry statuses", %{conn: conn} do
    email = "app-offline-batch@example.test"
    conn = sign_in!(conn, email)
    user = Accounts.get_user_by_email!(email, authorize?: false)

    plan =
      Plans.create_plan!(
        %{
          name: "Offline plan",
          intention: "Prove the offline outbox",
          starts_on: ~D[2026-06-22],
          ends_on: ~D[2026-07-20]
        },
        actor: user
      )

    event_type =
      Plans.create_event_type!(
        %{plan_id: plan.id, key: "water_break", name: "Water break"},
        actor: user
      )

    entry = %{
      plan_id: plan.id,
      event_type_id: event_type.id,
      effective_at: "2026-06-22T18:30:00Z",
      summary: "Logged while offline",
      client_device_id: "phone-1",
      client_operation_id: "offline-op-1"
    }

    bad_entry = %{
      plan_id: plan.id,
      event_type_id: Ash.UUID.generate(),
      effective_at: "2026-06-22T19:00:00Z",
      summary: "Broken reference",
      client_device_id: "phone-1",
      client_operation_id: "offline-op-2"
    }

    conn = post(conn, ~p"/api/app/offline-events", %{events: [entry, entry, bad_entry]})

    assert %{"results" => [first, second, third]} = json_response(conn, 200)

    assert %{"status" => "accepted", "eventInstanceId" => event_id} = first
    assert %{"status" => "duplicate", "eventInstanceId" => ^event_id} = second

    assert %{
             "status" => "needs_resolution",
             "eventInstanceId" => nil,
             "conflictCategory" => "missing_plan_record",
             "diagnostics" => [_diagnostic]
           } = third

    assert [_only_event] = Improve.Journal.read_journal!(plan, actor: user)

    conn = post(conn, ~p"/api/app/offline-events", %{events: []})
    assert %{"error" => %{"message" => message}} = json_response(conn, 422)
    assert message =~ "non-empty events list"
  end

  test "idempotency metadata without an operation id or key is rejected", %{conn: conn} do
    email = "app-idempotent-invalid@example.test"
    conn = sign_in!(conn, email)
    user = Accounts.get_user_by_email!(email, authorize?: false)

    plan =
      Plans.create_plan!(
        %{
          name: "Idempotency plan",
          intention: "Prove partial metadata fails",
          starts_on: ~D[2026-06-22],
          ends_on: ~D[2026-07-20]
        },
        actor: user
      )

    event_type =
      Plans.create_event_type!(
        %{plan_id: plan.id, key: "water_break", name: "Water break"},
        actor: user
      )

    conn =
      post(conn, ~p"/api/app/log-event", %{
        plan_id: plan.id,
        event_type_id: event_type.id,
        summary: "Drank water",
        client_device_id: "phone-1"
      })

    assert %{"error" => %{"message" => message}} = json_response(conn, 422)
    assert message =~ "operation ID or idempotency key"
  end

  test "signed-in users can skip a started session", %{conn: conn} do
    email = "app-session-skip@example.test"
    conn = sign_in!(conn, email)
    user = Accounts.get_user_by_email!(email, authorize?: false)
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
                   "session" => %{"state" => %{"sessionOccurrenceId" => occurrence_id}}
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

  test "signed-in users can log and correct vial doses from the app API", %{conn: conn} do
    conn = sign_in!(conn, "app-vial-flow@example.test")

    conn = post(conn, ~p"/api/app/demo-plans", %{kind: "vial_inventory"})
    response = json_response(conn, 200)
    plan_id = get_in(response, ["currentPlan", "id"])
    vial = plan_item(response, "retatrutide_vial_1")
    event_type = plan_event_type(response, "take_dose")

    assert get_in(vial, ["state", "calculatedState", "current_quantity"]) == "5000"
    assert get_in(vial, ["state", "calculatedState", "unit"]) == "mcg"

    conn =
      post(conn, ~p"/api/app/log-linked-event", %{
        plan_id: plan_id,
        item_id: vial["id"],
        event_type_id: event_type["id"],
        role: "source_vial",
        quantity: "250",
        unit: "mcg",
        effective_at: "2026-06-23T08:00:00Z",
        note: "Left abdomen"
      })

    response = json_response(conn, 200)
    vial = plan_item(response, "retatrutide_vial_1")

    assert get_in(vial, ["state", "calculatedState", "current_quantity"]) == "4750"

    assert [
             %{
               "id" => original_event_id,
               "itemLinks" => [%{"role" => "source_vial", "itemKey" => "retatrutide_vial_1"}],
               "itemEffects" => [
                 %{
                   "effectType" => "subtract_quantity",
                   "quantity" => "250",
                   "status" => "active"
                 }
               ]
             }
           ] = response["journal"]

    conn =
      post(conn, ~p"/api/app/correct-linked-event", %{
        plan_id: plan_id,
        original_event_id: original_event_id,
        item_id: vial["id"],
        event_type_id: event_type["id"],
        role: "source_vial",
        quantity: "200",
        unit: "mcg",
        effective_at: "2026-06-23T08:05:00Z",
        correction_note: "Dose amount corrected"
      })

    response = json_response(conn, 200)
    vial = plan_item(response, "retatrutide_vial_1")

    assert get_in(vial, ["state", "calculatedState", "current_quantity"]) == "4800"

    assert [
             %{
               "effectType" => "subtract_quantity",
               "quantity" => "200",
               "status" => "active"
             }
           ] = get_in(vial, ["state", "activeEffects"])

    assert Enum.any?(
             response["journal"],
             &(&1["id"] == original_event_id and &1["status"] == "corrected")
           )

    assert Enum.any?(
             response["journal"],
             &(&1["summary"] == "Corrected Take Dose for Retatrutide vial 1")
           )
  end

  defp alternate_push_item_key(recommended_key) do
    Enum.find(["chest_press", "shoulder_press", "cable_fly"], &(&1 != recommended_key))
  end

  defp plan_item(response, key) do
    response
    |> get_in(["planDetail", "items"])
    |> Enum.find(&(&1["key"] == key))
  end

  defp plan_event_type(response, key) do
    response
    |> get_in(["planDetail", "eventTypes"])
    |> Enum.find(&(&1["key"] == key))
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
