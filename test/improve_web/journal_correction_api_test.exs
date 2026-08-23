defmodule ImproveWeb.JournalCorrectionApiTest do
  use ImproveWeb.ConnCase, async: false

  alias Improve.Accounts
  alias Improve.Emails.LocalMailbox
  alias Improve.Fixtures.GymPlan
  alias Improve.Fixtures.VialPlan
  alias Improve.Journal
  alias Improve.Plans
  alias Improve.Sessions

  setup do
    LocalMailbox.clear()
    :ets.delete_all_objects(Improve.Hammer)
    :ok
  end

  test "corrects an active event without links or effects and preserves its lineage", %{
    conn: conn
  } do
    email = "journal-correction-simple@example.test"
    conn = sign_in!(conn, email)
    user = Accounts.get_user_by_email!(email, authorize?: false)
    {plan, event_type} = simple_plan!(user, "Simple corrections")

    original =
      log_simple_event!(user, plan, event_type,
        effective_at: ~U[2026-06-22 18:00:00Z],
        summary: "Read 20 pages",
        quantity: 20,
        unit: "pages",
        note: "Before bed",
        payload: %{"amount" => 20, "unit" => "pages"}
      )

    original_id = original.id

    assert [%{"id" => ^original_id, "correction" => %{"eligible" => true}}] =
             get_journal(conn, plan.id)["events"]

    response =
      conn
      |> correct_event_request(plan.id, original.id, %{
        effective_at: "2026-06-22T18:05:00Z",
        summary: "Read 35 pages",
        quantity: "35",
        unit: "pages",
        note: "Corrected after checking my notes",
        payload: %{"amount" => 35, "unit" => "pages"},
        correction_note: "The first amount was wrong"
      })
      |> json_response(200)

    assert %{
             "correctionResult" => %{
               "originalEventId" => ^original_id,
               "replacementEventId" => replacement_id
             }
           } = response

    assert is_binary(replacement_id)

    corrected = Journal.get_event!(original.id, actor: user)
    replacement = Journal.get_event!(replacement_id, actor: user)

    assert corrected.status == :corrected
    assert corrected.note == "The first amount was wrong"
    assert replacement.status == :active
    assert replacement.replaces_event_instance_id == original.id
    assert replacement.event_type_id == original.event_type_id
    assert replacement.effective_at == ~U[2026-06-22 18:05:00.000000Z]
    assert replacement.summary == "Read 35 pages"
    assert replacement.quantity == Decimal.new(35)
    assert replacement.unit == "pages"
    assert replacement.note == "Corrected after checking my notes"

    assert replacement.payload == %{
             "amount" => "35",
             "unit" => "pages",
             "note" => "Corrected after checking my notes"
           }

    assert event_links(user, original.id) == []
    assert event_links(user, replacement.id) == []
    assert event_effects(user, original.id) == []
    assert event_effects(user, replacement.id) == []
    assert event_count(user, plan.id) == 2
  end

  test "derives a stateful event's item context and replaces its effect", %{conn: conn} do
    email = "journal-correction-stateful@example.test"
    conn = sign_in!(conn, email)
    user = Accounts.get_user_by_email!(email, authorize?: false)

    %{plan: plan, event_type: event_type, items: items} =
      VialPlan.install!(user, starts_on: ~D[2026-06-22])

    vial = items.retatrutide_vial_1

    original =
      Journal.log_generic_event!(
        %{
          plan_id: plan.id,
          event_type_id: event_type.id,
          effective_at: ~U[2026-06-22 08:00:00Z],
          recorded_at: ~U[2026-06-22 08:01:00Z],
          summary: "Inventory use recorded",
          quantity: 250,
          unit: "mcg",
          note: "Original note",
          payload: %{"amount" => 250, "unit" => "mcg", "site" => "abdomen"},
          item_links: [%{role: "source_vial", item_id: vial.id}]
        },
        actor: user
      )

    [original_effect] = original.item_effects
    assert current_quantity(user, vial) == Decimal.new(4750)

    response =
      conn
      |> correct_event_request(plan.id, original.event.id, %{
        effective_at: "2026-06-22T08:00:00Z",
        summary: "Corrected inventory use",
        quantity: "300",
        unit: "mcg",
        note: "Corrected site and amount",
        payload: %{"amount" => 300, "unit" => "mcg", "site" => "thigh"},
        correction_note: "Amount corrected from 250 mcg to 300 mcg"
      })
      |> json_response(200)

    replacement_id = get_in(response, ["correctionResult", "replacementEventId"])
    assert is_binary(replacement_id)

    replacement = Journal.get_event!(replacement_id, actor: user)
    [replacement_link] = event_links(user, replacement_id)
    [voided_effect] = event_effects(user, original.event.id)
    [replacement_effect] = event_effects(user, replacement_id)

    assert replacement.event_type_id == original.event.event_type_id
    assert replacement.replaces_event_instance_id == original.event.id
    assert replacement_link.item_id == vial.id
    assert replacement_link.role == "source_vial"
    assert voided_effect.id == original_effect.id
    assert voided_effect.status == :voided
    assert replacement_effect.status == :active
    assert replacement_effect.effect_type == :subtract_quantity
    assert replacement_effect.quantity == Decimal.new(300)
    assert replacement_effect.unit == "mcg"
    assert replacement_effect.replaces_item_effect_id == original_effect.id
    assert current_quantity(user, vial) == Decimal.new(4700)
    assert event_count(user, plan.id) == 2
  end

  test "corrects a completed gym slot and relinks the result without changing session state", %{
    conn: conn
  } do
    email = "journal-correction-gym@example.test"
    conn = sign_in!(conn, email)
    user = Accounts.get_user_by_email!(email, authorize?: false)
    %{plan: plan} = GymPlan.install!(user, starts_on: ~D[2026-06-22])

    items = plan_items(user, plan.id)
    event_types = plan_event_types(user, plan.id)
    projection = Plans.project_today!(plan, actor: user, date: ~D[2026-06-22])
    [projected_occurrence] = projection.projected_session_occurrences

    started =
      Sessions.start_projected_session!(projected_occurrence,
        actor: user,
        started_at: ~U[2026-06-22 12:00:00Z]
      )

    slot_result =
      Enum.find(started.slot_results, &(&1.actual_item_id == items["chest_press"].id))

    original_payload = %{
      "sets" => 3,
      "reps" => 10,
      "load" => 45,
      "load_unit" => "kg",
      "rpe" => 8
    }

    original =
      Journal.log_session_item_event!(
        %{
          session_occurrence: started.session_occurrence,
          slot_result: slot_result,
          event_type: event_types["workout_exercise_performed"],
          item: items["chest_press"],
          role: "exercise",
          effective_at: ~U[2026-06-22 12:10:00Z],
          recorded_at: ~U[2026-06-22 12:11:00Z],
          summary: "Chest Press, 3 sets of 10 at 45 kg",
          note: "Original workout note",
          payload: original_payload
        },
        actor: user
      )

    assert original.slot_result.status == :completed
    assert original.slot_result.actual_payload == original_payload
    original_id = original.event.id

    corrected_payload = %{
      "sets" => 4,
      "reps" => 8,
      "load" => 50,
      "load_unit" => "kg",
      "rpe" => 9
    }

    stored_corrected_payload =
      Map.put(corrected_payload, "note", "Checked against the machine log")

    response =
      conn
      |> correct_event_request(plan.id, original.event.id, %{
        effective_at: "2026-06-22T12:12:00Z",
        summary: "Chest Press, 4 sets of 8 at 50 kg",
        quantity: nil,
        unit: nil,
        note: "Checked against the machine log",
        payload: corrected_payload,
        correction_note: "Workout numbers corrected"
      })
      |> json_response(200)

    replacement_id = get_in(response, ["correctionResult", "replacementEventId"])
    replacement = Journal.get_event!(replacement_id, actor: user)
    corrected_slot = Sessions.get_slot_result!(slot_result.id, actor: user)

    unchanged_session =
      Sessions.get_session_occurrence!(started.session_occurrence.id, actor: user)

    assert Journal.get_event!(original_id, actor: user).status == :corrected
    assert replacement.status == :active
    assert replacement.replaces_event_instance_id == original_id
    assert replacement.event_type_id == original.event.event_type_id
    assert replacement.session_occurrence_id == started.session_occurrence.id
    assert replacement.slot_result_id == slot_result.id
    assert replacement.payload == stored_corrected_payload

    assert [%{item_id: item_id, role: "exercise"}] = event_links(user, replacement_id)
    assert item_id == items["chest_press"].id
    assert corrected_slot.status == :completed
    assert corrected_slot.event_instance_id == replacement_id
    assert corrected_slot.actual_payload == stored_corrected_payload
    assert corrected_slot.session_occurrence_id == started.session_occurrence.id
    assert unchanged_session.status == :started
    assert event_count(user, plan.id) == 2
  end

  test "rejects a malformed supplied effective time without writing anything", %{conn: conn} do
    email = "journal-correction-invalid-time@example.test"
    conn = sign_in!(conn, email)
    user = Accounts.get_user_by_email!(email, authorize?: false)
    {plan, event_type} = simple_plan!(user, "Invalid correction input")
    original = log_simple_event!(user, plan, event_type, summary: "Original entry")

    response =
      conn
      |> correct_event_request(plan.id, original.id, %{
        effective_at: "not-a-date-time",
        summary: "Should not be written",
        quantity: nil,
        unit: nil,
        note: nil,
        payload: %{},
        correction_note: "This request is invalid"
      })
      |> json_response(422)

    assert %{
             "error" => %{
               "code" => "validation_failed",
               "message" => message,
               "details" => details
             }
           } = response

    assert is_binary(message) and message != ""

    assert Enum.any?(details, fn detail ->
             detail["field"] == "effective_at" and is_binary(detail["message"])
           end)

    assert Journal.get_event!(original.id, actor: user).status == :active
    assert event_count(user, plan.id) == 1
  end

  test "rejects already-corrected and cross-user events without extra writes", %{conn: conn} do
    owner_email = "journal-correction-owner@example.test"
    owner_conn = sign_in!(conn, owner_email)
    owner = Accounts.get_user_by_email!(owner_email, authorize?: false)
    {plan, event_type} = simple_plan!(owner, "Protected corrections")

    already_corrected =
      log_simple_event!(owner, plan, event_type, summary: "First owner entry")

    cross_user_target =
      log_simple_event!(owner, plan, event_type,
        effective_at: ~U[2026-06-22 10:00:00Z],
        summary: "Second owner entry"
      )

    owner_conn
    |> correct_event_request(plan.id, already_corrected.id, %{
      summary: "Corrected first owner entry",
      correction_note: "First correction"
    })
    |> json_response(200)

    assert event_count(owner, plan.id) == 3

    already_corrected_response =
      owner_conn
      |> correct_event_request(plan.id, already_corrected.id, %{
        summary: "A second replacement must not be created",
        correction_note: "Second correction attempt"
      })
      |> json_response(422)

    assert %{"error" => %{"code" => "validation_failed", "details" => details}} =
             already_corrected_response

    assert Enum.any?(details, &String.contains?(&1["message"], "already been corrected"))
    assert event_count(owner, plan.id) == 3

    other_conn = sign_in!(build_conn(), "journal-correction-intruder@example.test")

    assert %{"error" => %{"code" => "not_found"}} =
             other_conn
             |> correct_event_request(plan.id, cross_user_target.id, %{
               summary: "Intruder replacement must not be created",
               correction_note: "Cross-user attempt"
             })
             |> json_response(404)

    assert Journal.get_event!(cross_user_target.id, actor: owner).status == :active
    assert event_count(owner, plan.id) == 3
  end

  defp simple_plan!(user, name) do
    plan =
      Plans.create_plan!(
        %{
          name: name,
          intention: "Exercise the correction API",
          starts_on: ~D[2026-06-22],
          ends_on: ~D[2026-07-20]
        },
        actor: user
      )

    event_type =
      Plans.create_event_type!(
        %{
          plan_id: plan.id,
          key: "journal_entry",
          name: "Journal Entry"
        },
        actor: user
      )

    {plan, event_type}
  end

  defp log_simple_event!(user, plan, event_type, opts) do
    effective_at = Keyword.get(opts, :effective_at, ~U[2026-06-22 09:00:00Z])

    Journal.log_generic_event!(
      %{
        plan_id: plan.id,
        event_type_id: event_type.id,
        effective_at: effective_at,
        recorded_at: DateTime.add(effective_at, 60, :second),
        summary: Keyword.fetch!(opts, :summary),
        quantity: Keyword.get(opts, :quantity),
        unit: Keyword.get(opts, :unit),
        note: Keyword.get(opts, :note),
        payload: Keyword.get(opts, :payload, %{})
      },
      actor: user
    ).event
  end

  defp correct_event_request(conn, plan_id, original_event_id, overrides) do
    params =
      Map.merge(
        %{
          plan_id: plan_id,
          original_event_id: original_event_id,
          effective_at: "2026-06-22T09:00:00Z",
          summary: "Corrected journal entry",
          quantity: nil,
          unit: nil,
          note: nil,
          payload: %{},
          correction_note: "Corrected from the journal"
        },
        overrides
      )

    conn
    |> recycle()
    |> post("/api/app/correct-event", params)
  end

  defp get_journal(conn, plan_id) do
    conn
    |> recycle()
    |> get("/api/app/journal?" <> URI.encode_query(%{plan_id: plan_id}))
    |> json_response(200)
  end

  defp event_links(user, event_id) do
    Journal.list_event_item_links!(
      actor: user,
      query: [filter: [event_instance_id: event_id], sort: [inserted_at: :asc, id: :asc]]
    )
  end

  defp event_effects(user, event_id) do
    Journal.list_item_effects!(
      actor: user,
      query: [filter: [event_instance_id: event_id], sort: [inserted_at: :asc, id: :asc]]
    )
  end

  defp event_count(user, plan_id) do
    Journal.list_events!(actor: user, query: [filter: [plan_id: plan_id]])
    |> length()
  end

  defp current_quantity(user, item) do
    Journal.get_item_state!(item, actor: user).calculated_state.current_quantity
  end

  defp plan_items(user, plan_id) do
    Plans.list_items!(actor: user, query: [filter: [plan_id: plan_id]])
    |> Map.new(&{&1.key, &1})
  end

  defp plan_event_types(user, plan_id) do
    Plans.list_event_types!(actor: user, query: [filter: [plan_id: plan_id]])
    |> Map.new(&{&1.key, &1})
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
