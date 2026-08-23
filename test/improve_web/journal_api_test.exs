defmodule ImproveWeb.JournalApiTest do
  use ImproveWeb.ConnCase, async: false

  alias Improve.Accounts
  alias Improve.Emails.LocalMailbox
  alias Improve.Fixtures.VialPlan
  alias Improve.Journal
  alias Improve.Plans

  setup do
    LocalMailbox.clear()
    :ets.delete_all_objects(Improve.Hammer)
    :ok
  end

  test "journal reads require authentication and do not expose another user's plan", %{conn: conn} do
    unauthenticated = get(conn, journal_path("00000000-0000-0000-0000-000000000000"))

    assert %{"error" => %{"code" => "unauthenticated"}} =
             json_response(unauthenticated, 401)

    owner_email = "journal-api-owner@example.test"
    owner_conn = sign_in!(build_conn(), owner_email)
    owner = Accounts.get_user_by_email!(owner_email, authorize?: false)
    %{plan: plan} = VialPlan.install!(owner, starts_on: ~D[2026-06-22])

    assert %{"planId" => plan_id, "events" => []} =
             owner_conn
             |> recycle()
             |> get(journal_path(plan.id))
             |> json_response(200)

    assert plan_id == plan.id

    other_conn = sign_in!(build_conn(), "journal-api-other@example.test")

    assert %{"error" => %{"code" => "not_found"}} =
             other_conn
             |> recycle()
             |> get(journal_path(plan.id))
             |> json_response(404)
  end

  test "journal pages are deterministically newest-first without duplicates", %{conn: conn} do
    email = "journal-api-pages@example.test"
    conn = sign_in!(conn, email)
    user = Accounts.get_user_by_email!(email, authorize?: false)
    {plan, event_type} = simple_journal_plan!(user, "Pagination journal")

    oldest =
      log_simple_event!(user, plan, event_type, "Oldest",
        effective_at: ~U[2026-06-22 09:00:00Z],
        recorded_at: ~U[2026-06-22 09:01:00Z]
      )

    middle =
      log_simple_event!(user, plan, event_type, "Middle",
        effective_at: ~U[2026-06-22 10:00:00Z],
        recorded_at: ~U[2026-06-22 10:01:00Z]
      )

    same_time_earlier =
      log_simple_event!(user, plan, event_type, "Same time, recorded earlier",
        effective_at: ~U[2026-06-22 11:00:00Z],
        recorded_at: ~U[2026-06-22 11:01:00Z]
      )

    same_time_later =
      log_simple_event!(user, plan, event_type, "Same time, recorded later",
        effective_at: ~U[2026-06-22 11:00:00Z],
        recorded_at: ~U[2026-06-22 11:02:00Z]
      )

    first_page = get_journal(conn, plan.id, %{limit: 2})

    assert Enum.map(first_page["events"], & &1["id"]) == [
             same_time_later.id,
             same_time_earlier.id
           ]

    assert %{
             "limit" => 2,
             "hasMore" => true,
             "nextCursor" => cursor
           } = first_page["pageInfo"]

    assert is_binary(cursor)

    second_page = get_journal(conn, plan.id, %{limit: 2, cursor: cursor})

    assert Enum.map(second_page["events"], & &1["id"]) == [middle.id, oldest.id]

    assert %{"limit" => 2, "hasMore" => false, "nextCursor" => nil} =
             second_page["pageInfo"]

    all_ids = Enum.map(first_page["events"] ++ second_page["events"], & &1["id"])

    assert length(all_ids) == length(Enum.uniq(all_ids))

    assert MapSet.new(all_ids) ==
             MapSet.new([oldest.id, middle.id, same_time_earlier.id, same_time_later.id])
  end

  test "journal filters compose with full event, item-link, and effect context", %{conn: conn} do
    email = "journal-api-filters@example.test"
    conn = sign_in!(conn, email)
    user = Accounts.get_user_by_email!(email, authorize?: false)

    %{plan: plan, event_type: dose_type, items: items} =
      VialPlan.install!(user, starts_on: ~D[2026-06-22])

    track =
      Plans.create_track!(
        %{
          plan_id: plan.id,
          event_type_id: dose_type.id,
          key: "inventory_check",
          name: "Inventory check"
        },
        actor: user
      )

    note_type =
      Plans.create_event_type!(
        %{
          plan_id: plan.id,
          key: "journal_note",
          name: "Journal Note"
        },
        actor: user
      )

    standalone =
      log_dose!(user, plan, dose_type, items.retatrutide_vial_1, 250,
        summary: "Standalone inventory use",
        effective_at: ~U[2026-06-22 08:00:00Z],
        payload: %{
          "amount" => 250,
          "unit" => "mcg",
          "route" => "recorded privately"
        }
      )

    tracked =
      log_dose!(user, plan, dose_type, items.retatrutide_vial_1, 100,
        summary: "Tracked inventory use",
        effective_at: ~U[2026-06-22 09:00:00Z],
        track_id: track.id
      )

    skipped =
      Journal.log_generic_event!(
        %{
          plan_id: plan.id,
          event_type_id: note_type.id,
          effective_at: ~U[2026-06-22 10:00:00Z],
          recorded_at: ~U[2026-06-22 10:01:00Z],
          summary: "Skipped journal note",
          status: :skipped
        },
        actor: user
      ).event

    event_type_page = get_journal(conn, plan.id, %{event_type_id: dose_type.id})

    assert MapSet.new(Enum.map(event_type_page["events"], & &1["id"])) ==
             MapSet.new([standalone.event.id, tracked.event.id])

    assert %{"eventTypeId" => event_type_id} = event_type_page["appliedFilters"]
    assert event_type_id == dose_type.id

    tracked_event_id = tracked.event.id

    assert [%{"id" => ^tracked_event_id, "trackName" => "Inventory check"}] =
             get_journal(conn, plan.id, %{track_id: track.id})["events"]

    assert MapSet.new(
             get_journal(conn, plan.id, %{item_id: items.retatrutide_vial_1.id})["events"]
             |> Enum.map(& &1["id"])
           ) == MapSet.new([standalone.event.id, tracked.event.id])

    skipped_event_id = skipped.id

    assert [%{"id" => ^skipped_event_id, "status" => "skipped"}] =
             get_journal(conn, plan.id, %{status: "skipped"})["events"]

    standalone_json = Enum.find(event_type_page["events"], &(&1["id"] == standalone.event.id))

    assert %{
             "eventTypeKey" => "take_dose",
             "eventTypeName" => "Take Dose",
             "summary" => "Standalone inventory use",
             "quantity" => "250",
             "unit" => "mcg",
             "payload" => %{
               "amount" => 250,
               "unit" => "mcg",
               "route" => "recorded privately"
             },
             "origin" => "manual",
             "itemLinks" => [
               %{
                 "role" => "source_vial",
                 "itemKey" => "retatrutide_vial_1",
                 "itemName" => "Retatrutide vial 1"
               }
             ],
             "itemEffects" => [
               %{
                 "effectType" => "subtract_quantity",
                 "quantity" => "250",
                 "unit" => "mcg",
                 "status" => "active",
                 "itemKey" => "retatrutide_vial_1",
                 "itemName" => "Retatrutide vial 1",
                 "payload" => %{
                   "rule" => %{
                     "role" => "source_vial",
                     "effect_type" => "subtract_quantity"
                   }
                 }
               }
             ],
             "correction" => %{
               "eligible" => true,
               "unavailableReason" => nil,
               "replaces" => nil,
               "replacedBy" => []
             }
           } = standalone_json

    assert %{"eventTypes" => event_types, "tracks" => tracks, "items" => filter_items} =
             event_type_page["filterOptions"]

    assert Enum.any?(event_types, &(&1["id"] == dose_type.id))
    assert Enum.any?(tracks, &(&1["id"] == track.id))
    assert Enum.any?(filter_items, &(&1["id"] == items.retatrutide_vial_1.id))
  end

  test "journal correction context links the corrected event to its active replacement", %{
    conn: conn
  } do
    email = "journal-api-correction@example.test"
    conn = sign_in!(conn, email)
    user = Accounts.get_user_by_email!(email, authorize?: false)

    %{plan: plan, event_type: event_type, items: items} =
      VialPlan.install!(user, starts_on: ~D[2026-06-22])

    original =
      Journal.log_linked_item_event!(
        %{
          plan: plan,
          event_type: event_type,
          linked_item: items.retatrutide_vial_1,
          role: "source_vial",
          quantity: 250,
          unit: "mcg",
          effective_at: ~U[2026-06-22 08:00:00Z],
          recorded_at: ~U[2026-06-22 08:01:00Z],
          summary: "Inventory use recorded"
        },
        actor: user
      )

    before = get_journal(conn, plan.id)

    assert [
             %{
               "id" => original_event_id,
               "correction" => %{
                 "eligible" => true,
                 "unavailableReason" => nil,
                 "replaces" => nil,
                 "replacedBy" => []
               }
             }
           ] = before["events"]

    assert original_event_id == original.event.id
    [original_effect] = original.item_effects

    correction =
      Journal.correct_linked_item_event!(
        %{
          plan: plan,
          event_type: event_type,
          linked_item: items.retatrutide_vial_1,
          role: "source_vial",
          original_event: original.event,
          original_effect: original_effect,
          quantity: 200,
          unit: "mcg",
          effective_at: ~U[2026-06-22 08:00:00Z],
          recorded_at: ~U[2026-06-22 08:05:00Z],
          corrected_at: ~U[2026-06-22 08:05:00Z],
          summary: "Corrected inventory use",
          correction_note: "Amount corrected"
        },
        actor: user
      )

    replacement_id = correction.replacement_event.id
    after_page = get_journal(conn, plan.id)
    original_json = Enum.find(after_page["events"], &(&1["id"] == original.event.id))
    replacement_json = Enum.find(after_page["events"], &(&1["id"] == replacement_id))

    assert %{
             "status" => "corrected",
             "correctedAt" => "2026-06-22T08:05:00.000000Z",
             "voidedAt" => nil,
             "correction" => %{
               "eligible" => false,
               "unavailableReason" => reason,
               "replaces" => nil,
               "replacedBy" => [
                 %{
                   "id" => ^replacement_id,
                   "summary" => "Corrected inventory use",
                   "status" => "active"
                 }
               ]
             },
             "itemEffects" => [%{"status" => "voided", "voidedAt" => voided_at}]
           } = original_json

    assert is_binary(reason)
    assert voided_at == "2026-06-22T08:05:00.000000Z"

    assert %{
             "status" => "active",
             "replacesEventInstanceId" => ^original_event_id,
             "correction" => %{
               "eligible" => true,
               "unavailableReason" => nil,
               "replaces" => %{
                 "id" => ^original_event_id,
                 "summary" => "Inventory use recorded",
                 "status" => "corrected"
               },
               "replacedBy" => []
             }
           } = replacement_json
  end

  test "malformed journal pagination and filters return structured validation errors", %{
    conn: conn
  } do
    email = "journal-api-errors@example.test"
    conn = sign_in!(conn, email)
    user = Accounts.get_user_by_email!(email, authorize?: false)
    {plan, _event_type} = simple_journal_plan!(user, "Invalid journal requests")

    for params <- [
          %{limit: "not-a-number"},
          %{status: "not-a-status"},
          %{cursor: "not-a-cursor"}
        ] do
      response =
        conn
        |> recycle()
        |> get(journal_path(plan.id, params))
        |> json_response(422)

      assert %{
               "error" => %{
                 "code" => "validation_failed",
                 "message" => message,
                 "details" => details
               }
             } = response

      assert is_binary(message) and message != ""
      assert is_list(details) and details != []
    end
  end

  defp simple_journal_plan!(user, name) do
    plan =
      Plans.create_plan!(
        %{
          name: name,
          intention: "Exercise the Journal API",
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

  defp log_simple_event!(user, plan, event_type, summary, opts) do
    Journal.log_generic_event!(
      %{
        plan_id: plan.id,
        event_type_id: event_type.id,
        effective_at: Keyword.fetch!(opts, :effective_at),
        recorded_at: Keyword.fetch!(opts, :recorded_at),
        summary: summary
      },
      actor: user
    ).event
  end

  defp log_dose!(user, plan, event_type, item, quantity, opts) do
    effective_at = Keyword.fetch!(opts, :effective_at)

    Journal.log_generic_event!(
      %{
        plan_id: plan.id,
        event_type_id: event_type.id,
        track_id: Keyword.get(opts, :track_id),
        effective_at: effective_at,
        recorded_at: DateTime.add(effective_at, 60, :second),
        summary: Keyword.fetch!(opts, :summary),
        quantity: quantity,
        unit: "mcg",
        payload: Keyword.get(opts, :payload, %{"amount" => quantity, "unit" => "mcg"}),
        item_links: [%{role: "source_vial", item_id: item.id}]
      },
      actor: user
    )
  end

  defp get_journal(conn, plan_id, params \\ %{}) do
    conn
    |> recycle()
    |> get(journal_path(plan_id, params))
    |> json_response(200)
  end

  defp journal_path(plan_id, params \\ %{}) do
    "/api/app/journal?" <> URI.encode_query(Map.put(params, :plan_id, plan_id))
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
