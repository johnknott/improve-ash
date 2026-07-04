defmodule Improve.App.UiApi do
  @moduledoc """
  Product-shaped API used by the first Svelte UI.

  Phoenix controllers should stay thin and call this module for app workflow
  orchestration and dashboard serialization. Core business rules still live on
  Ash resources/domains and in the existing product-facing `Improve.App`
  workflows.
  """

  alias Improve.Journal
  alias Improve.App
  alias Improve.Plans
  alias Improve.Sessions
  alias Improve.Fixtures.DemoPlans

  def dashboard(actor, params) do
    with {:ok, plans} <- Plans.list_plans(actor: actor),
         {:ok, plan} <- current_plan(plans, params),
         {:ok, payload} <- dashboard_payload(plan, plans, actor, params) do
      {:ok, payload}
    else
      {:error, :no_plan} ->
        {:ok, empty_dashboard()}

      {:error, error} ->
        {:error, error}
    end
  end

  def log_event(actor, params) do
    with {:ok, attrs} <- log_attrs(params),
         {:ok, result} <- Journal.log_generic_event(attrs, actor: actor) do
      {:ok, %{event: event_json(result.event, nil, nil)}}
    else
      {:error, diagnostics} when is_list(diagnostics) ->
        {:error, diagnostics}

      {:error, error} ->
        {:error, error}
    end
  end

  def log_linked_event(actor, params) do
    with {:ok, plan} <- get_owned_plan(params, actor),
         {:ok, linked_item} <- get_plan_item(params, plan.id, actor),
         {:ok, event_type} <- get_plan_event_type(params, plan.id, actor),
         {:ok, _result} <- log_linked_event(plan, linked_item, event_type, params, actor),
         {:ok, payload} <- mutation_payload(plan, actor, params, [:today, :journal, :planDetail]) do
      {:ok, payload}
    else
      {:error, diagnostics} when is_list(diagnostics) ->
        {:error, diagnostics}

      {:error, error} ->
        {:error, error}
    end
  end

  def submit_offline_events(actor, params) do
    case Map.get(params, "events") do
      entries when is_list(entries) and entries != [] ->
        {:ok, result} =
          Journal.submit_offline_event_batch(Enum.map(entries, &offline_entry_attrs/1),
            actor: actor
          )

        {:ok, %{results: Enum.map(result.results, &offline_result_json/1)}}

      _missing ->
        {:error, ["Offline batch needs a non-empty events list."]}
    end
  end

  defp offline_entry_attrs(entry) when is_map(entry) do
    %{
      plan_id: map_value(entry, "plan_id"),
      event_type_id: map_value(entry, "event_type_id"),
      track_id: blank_to_nil(map_value(entry, "track_id")),
      session_occurrence_id: blank_to_nil(map_value(entry, "session_occurrence_id")),
      slot_result_id: blank_to_nil(map_value(entry, "slot_result_id")),
      effective_at: parse_datetime(map_value(entry, "effective_at")),
      recorded_at:
        parse_datetime(map_value(entry, "recorded_at")) ||
          parse_datetime(map_value(entry, "effective_at")),
      summary: blank_to_nil(map_value(entry, "summary")) || "Logged offline event",
      quantity: blank_to_nil(map_value(entry, "quantity")),
      unit: blank_to_nil(map_value(entry, "unit")),
      note: blank_to_nil(map_value(entry, "note")),
      payload: map_value(entry, "payload") || %{},
      origin: :offline_sync,
      item_links: item_links(map_value(entry, "item_links") || []),
      idempotency: idempotency_from_params(entry)
    }
  end

  defp offline_entry_attrs(entry), do: entry

  defp offline_result_json(result) do
    %{
      index: result.index,
      status: Atom.to_string(result.status),
      clientOperationId: result.client_operation_id,
      idempotencyKey: result.idempotency_key,
      eventInstanceId: result.event_instance_id,
      conflictCategory: result.conflict_category && Atom.to_string(result.conflict_category),
      diagnostics: Enum.map(result.diagnostics, &offline_diagnostic_json/1)
    }
  end

  defp offline_diagnostic_json(diagnostic) when is_binary(diagnostic), do: diagnostic
  defp offline_diagnostic_json(%{message: message}), do: message
  defp offline_diagnostic_json(diagnostic), do: inspect(diagnostic)

  def correct_linked_event(actor, params) do
    with {:ok, plan} <- get_owned_plan(params, actor),
         {:ok, original_event} <- get_event(params, actor),
         :ok <- ensure_event_plan(original_event, plan),
         {:ok, linked_item} <- get_plan_item(params, plan.id, actor),
         {:ok, original_effect} <- get_active_effect(original_event, linked_item, actor),
         {:ok, event_type} <- get_plan_event_type(params, plan.id, actor),
         {:ok, _result} <-
           correct_linked_event(
             plan,
             linked_item,
             event_type,
             original_event,
             original_effect,
             params,
             actor
           ),
         {:ok, payload} <- mutation_payload(plan, actor, params, [:today, :journal, :planDetail]) do
      {:ok, payload}
    else
      {:error, diagnostics} when is_list(diagnostics) ->
        {:error, diagnostics}

      {:error, error} ->
        {:error, error}
    end
  end

  def create_plan(actor, params) do
    with {:ok, attrs} <- create_plan_attrs(params),
         {:ok, plan} <- persist_created_plan(attrs, actor),
         {:ok, payload} <-
           mutation_payload(plan, actor, params, [:plans, :currentPlan, :today, :planDetail]) do
      {:ok, payload}
    else
      {:error, diagnostics} when is_list(diagnostics) ->
        {:error, diagnostics}

      {:error, error} ->
        {:error, error}
    end
  end

  def update_plan(actor, params) do
    with {:ok, plan} <- get_owned_plan(params, actor),
         {:ok, attrs} <- create_plan_attrs(params),
         {:ok, plan} <- persist_updated_plan(plan, attrs, actor),
         {:ok, payload} <-
           mutation_payload(plan, actor, params, [:plans, :currentPlan, :today, :planDetail]) do
      {:ok, payload}
    else
      {:error, diagnostics} when is_list(diagnostics) ->
        {:error, diagnostics}

      {:error, error} ->
        {:error, error}
    end
  end

  def create_track(actor, params) do
    with {:ok, plan} <- get_owned_plan(params, actor),
         {:ok, attrs} <- create_track_attrs(params),
         {:ok, _track} <- persist_track(plan, attrs, actor),
         {:ok, payload} <-
           mutation_payload(plan, actor, params, [:plans, :currentPlan, :today, :planDetail]) do
      {:ok, payload}
    else
      {:error, diagnostics} when is_list(diagnostics) ->
        {:error, diagnostics}

      {:error, error} ->
        {:error, error}
    end
  end

  def update_track(actor, params) do
    with {:ok, plan} <- get_owned_plan(params, actor),
         {:ok, track} <- get_plan_resource(params, "track_id", plan.id, &Plans.get_track/2, actor),
         {:ok, attrs} <- update_track_attrs(params),
         {:ok, _track} <- Plans.update_track(track, attrs, actor: actor),
         {:ok, payload} <-
           mutation_payload(plan, actor, params, [:plans, :currentPlan, :today, :planDetail]) do
      {:ok, payload}
    else
      {:error, diagnostics} when is_list(diagnostics) -> {:error, diagnostics}
      {:error, error} -> {:error, error}
    end
  end

  def create_session_template(actor, params) do
    with {:ok, plan} <- get_owned_plan(params, actor),
         {:ok, attrs} <- session_template_attrs(params),
         {:ok, _template} <-
           Plans.create_session_template(Map.put(attrs, :plan_id, plan.id), actor: actor),
         {:ok, payload} <-
           mutation_payload(plan, actor, params, [:plans, :currentPlan, :today, :planDetail]) do
      {:ok, payload}
    else
      {:error, diagnostics} when is_list(diagnostics) -> {:error, diagnostics}
      {:error, error} -> {:error, error}
    end
  end

  def update_session_template(actor, params) do
    with {:ok, plan} <- get_owned_plan(params, actor),
         {:ok, template} <-
           get_plan_resource(
             params,
             "session_template_id",
             plan.id,
             &Plans.get_session_template/2,
             actor
           ),
         {:ok, attrs} <- session_template_attrs(params),
         {:ok, _template} <- Plans.update_session_template(template, attrs, actor: actor),
         {:ok, payload} <-
           mutation_payload(plan, actor, params, [:plans, :currentPlan, :today, :planDetail]) do
      {:ok, payload}
    else
      {:error, diagnostics} when is_list(diagnostics) -> {:error, diagnostics}
      {:error, error} -> {:error, error}
    end
  end

  def create_session_slot(actor, params) do
    with {:ok, plan} <- get_owned_plan(params, actor),
         {:ok, attrs} <- session_slot_attrs(params),
         {:ok, _slot} <-
           Plans.create_session_slot(Map.put(attrs, :plan_id, plan.id), actor: actor),
         {:ok, payload} <-
           mutation_payload(plan, actor, params, [:plans, :currentPlan, :today, :planDetail]) do
      {:ok, payload}
    else
      {:error, diagnostics} when is_list(diagnostics) -> {:error, diagnostics}
      {:error, error} -> {:error, error}
    end
  end

  def update_session_slot(actor, params) do
    with {:ok, plan} <- get_owned_plan(params, actor),
         {:ok, slot} <-
           get_plan_resource(params, "session_slot_id", plan.id, &Plans.get_session_slot/2, actor),
         {:ok, attrs} <- session_slot_attrs(params),
         {:ok, _slot} <- Plans.update_session_slot(slot, attrs, actor: actor),
         {:ok, payload} <-
           mutation_payload(plan, actor, params, [:plans, :currentPlan, :today, :planDetail]) do
      {:ok, payload}
    else
      {:error, diagnostics} when is_list(diagnostics) -> {:error, diagnostics}
      {:error, error} -> {:error, error}
    end
  end

  def create_item(actor, params) do
    with {:ok, plan} <- get_owned_plan(params, actor),
         {:ok, attrs} <- item_attrs(params),
         {:ok, _item} <- Plans.create_item(Map.put(attrs, :plan_id, plan.id), actor: actor),
         {:ok, payload} <-
           mutation_payload(plan, actor, params, [:plans, :currentPlan, :today, :planDetail]) do
      {:ok, payload}
    else
      {:error, diagnostics} when is_list(diagnostics) -> {:error, diagnostics}
      {:error, error} -> {:error, error}
    end
  end

  def update_item(actor, params) do
    with {:ok, plan} <- get_owned_plan(params, actor),
         {:ok, item} <-
           get_plan_resource(params, "item_id", plan.id, &Plans.get_item/2, actor),
         {:ok, attrs} <- item_attrs(params),
         {:ok, _item} <- Plans.update_item(item, attrs, actor: actor),
         {:ok, payload} <-
           mutation_payload(plan, actor, params, [:plans, :currentPlan, :today, :planDetail]) do
      {:ok, payload}
    else
      {:error, diagnostics} when is_list(diagnostics) -> {:error, diagnostics}
      {:error, error} -> {:error, error}
    end
  end

  def create_item_type(actor, params) do
    with {:ok, plan} <- get_owned_plan(params, actor),
         {:ok, attrs} <- item_type_attrs(params),
         {:ok, _item_type} <-
           Plans.create_item_type(Map.put(attrs, :plan_id, plan.id), actor: actor),
         {:ok, payload} <-
           mutation_payload(plan, actor, params, [:plans, :currentPlan, :today, :planDetail]) do
      {:ok, payload}
    else
      {:error, diagnostics} when is_list(diagnostics) -> {:error, diagnostics}
      {:error, error} -> {:error, error}
    end
  end

  def update_item_type(actor, params) do
    with {:ok, plan} <- get_owned_plan(params, actor),
         {:ok, item_type} <-
           get_plan_resource(params, "item_type_id", plan.id, &Plans.get_item_type/2, actor),
         {:ok, attrs} <- item_type_attrs(params),
         {:ok, _item_type} <- Plans.update_item_type(item_type, attrs, actor: actor),
         {:ok, payload} <-
           mutation_payload(plan, actor, params, [:plans, :currentPlan, :today, :planDetail]) do
      {:ok, payload}
    else
      {:error, diagnostics} when is_list(diagnostics) -> {:error, diagnostics}
      {:error, error} -> {:error, error}
    end
  end

  def create_event_type(actor, params) do
    with {:ok, plan} <- get_owned_plan(params, actor),
         {:ok, attrs} <- event_type_attrs(params),
         {:ok, _event_type} <-
           Plans.create_event_type(Map.put(attrs, :plan_id, plan.id), actor: actor),
         {:ok, payload} <-
           mutation_payload(plan, actor, params, [:plans, :currentPlan, :today, :planDetail]) do
      {:ok, payload}
    else
      {:error, diagnostics} when is_list(diagnostics) -> {:error, diagnostics}
      {:error, error} -> {:error, error}
    end
  end

  def update_event_type(actor, params) do
    with {:ok, plan} <- get_owned_plan(params, actor),
         {:ok, event_type} <-
           get_plan_resource(params, "event_type_id", plan.id, &Plans.get_event_type/2, actor),
         {:ok, attrs} <- event_type_attrs(params),
         {:ok, _event_type} <- Plans.update_event_type(event_type, attrs, actor: actor),
         {:ok, payload} <-
           mutation_payload(plan, actor, params, [:plans, :currentPlan, :today, :planDetail]) do
      {:ok, payload}
    else
      {:error, diagnostics} when is_list(diagnostics) -> {:error, diagnostics}
      {:error, error} -> {:error, error}
    end
  end

  def install_demo_plan(actor, params) do
    with {:ok, plan} <- install_or_select_demo_plan(actor, Map.get(params, "kind")),
         {:ok, payload} <-
           mutation_payload(plan, actor, params, [:plans, :currentPlan, :today, :planDetail]) do
      {:ok, payload}
    else
      {:error, error} -> {:error, error}
    end
  end

  def start_session(actor, params) do
    with {:ok, plan} <- get_owned_plan(params, actor),
         {:ok, projection} <- Plans.project_today(plan, actor: actor, date: request_date(params)),
         {:ok, template} <- get_projected_session_template(params, projection, actor),
         :ok <- maybe_start_projected_session(projection, template, actor),
         {:ok, payload} <- mutation_payload(plan, actor, params, [:today, :journal]) do
      {:ok, payload}
    else
      {:error, error} -> {:error, error}
    end
  end

  def log_session_slot(actor, params) do
    with {:ok, occurrence} <- get_session_occurrence(params, actor),
         {:ok, started_session} <- started_session(occurrence, actor),
         {:ok, _result} <- log_session_slot_event(started_session, params, actor),
         {:ok, plan} <- Plans.get_plan(occurrence.plan_id, actor: actor),
         {:ok, payload} <- mutation_payload(plan, actor, params, [:today, :journal]) do
      {:ok, payload}
    else
      {:error, diagnostics} when is_list(diagnostics) ->
        {:error, diagnostics}

      {:error, error} ->
        {:error, error}
    end
  end

  def swap_session_slot(actor, params) do
    with {:ok, slot_result} <- get_slot_result(params, actor),
         {:ok, item} <- get_slot_actual_item(params, slot_result.plan_id, actor),
         {:ok, _slot_result} <- swap_slot_result(slot_result, item, params, actor),
         {:ok, plan} <- Plans.get_plan(slot_result.plan_id, actor: actor),
         {:ok, payload} <- mutation_payload(plan, actor, params, [:today, :journal]) do
      {:ok, payload}
    else
      {:error, diagnostics} when is_list(diagnostics) ->
        {:error, diagnostics}

      {:error, error} ->
        {:error, error}
    end
  end

  def complete_session(actor, params) do
    update_session_status(actor, params, :complete)
  end

  def skip_session(actor, params) do
    update_session_status(actor, params, :skip)
  end

  @dashboard_slices [:plans, :currentPlan, :today, :journal, :planDetail]

  defp dashboard_payload(plan, plans, actor, params) do
    build_dashboard_payload(plan, plans, actor, params, @dashboard_slices)
  end

  # Mutations return only the slices they invalidate; clients merge the
  # partial payload into their cached dashboard.
  defp mutation_payload(plan, actor, params, slices) do
    with {:ok, plans} <- maybe_list_plans(actor, :plans in slices) do
      build_dashboard_payload(plan, plans, actor, params, slices)
    end
  end

  defp maybe_list_plans(actor, true), do: Plans.list_plans(actor: actor)
  defp maybe_list_plans(_actor, false), do: {:ok, []}

  defp maybe_query(true, _default, query), do: query.()
  defp maybe_query(false, default, _query), do: {:ok, default}

  defp put_slice(payload, true, key, build), do: Map.put(payload, key, build.())
  defp put_slice(payload, false, _key, _build), do: payload

  defp build_dashboard_payload(plan, plans, actor, params, slices) do
    date = parse_date(Map.get(params, "date")) || Date.utc_today()
    plan_detail? = :planDetail in slices
    journal? = :journal in slices
    summary? = :currentPlan in slices or plan_detail?

    with {:ok, summary} <-
           maybe_query(summary?, nil, fn -> Plans.summarize_plan(plan, actor: actor) end),
         {:ok, projections} <-
           Plans.project_dates(plan, [date | next_days(date, 3)], actor: actor, as_of_date: date),
         [projection | upcoming_projections] = projections,
         {:ok, journal_events} <-
           maybe_query(journal?, [], fn -> Journal.read_journal(plan, actor: actor) end),
         {:ok, items} <- Plans.list_items(actor: actor, query: [filter: [plan_id: plan.id]]),
         {:ok, item_types} <-
           maybe_query(plan_detail?, [], fn ->
             Plans.list_item_types(actor: actor, query: [filter: [plan_id: plan.id]])
           end),
         {:ok, event_types} <-
           Plans.list_event_types(actor: actor, query: [filter: [plan_id: plan.id]]),
         {:ok, tracks} <-
           maybe_query(plan_detail?, [], fn ->
             Plans.list_tracks(actor: actor, query: [filter: [plan_id: plan.id]])
           end),
         {:ok, pools} <-
           maybe_query(plan_detail?, [], fn ->
             Plans.list_pools(actor: actor, query: [filter: [plan_id: plan.id]])
           end),
         {:ok, pool_memberships} <-
           maybe_query(plan_detail?, [], fn ->
             Plans.list_pool_memberships(actor: actor, query: [filter: [plan_id: plan.id]])
           end),
         {:ok, session_templates} <-
           maybe_query(plan_detail?, [], fn ->
             Plans.list_session_templates(actor: actor, query: [filter: [plan_id: plan.id]])
           end),
         {:ok, session_slots} <-
           Plans.list_session_slots(actor: actor, query: [filter: [plan_id: plan.id]]),
         {:ok, schedules} <-
           maybe_query(plan_detail?, [], fn ->
             Plans.list_schedules(actor: actor, query: [filter: [plan_id: plan.id]])
           end),
         {:ok, slot_results} <-
           Sessions.list_slot_results(actor: actor, query: [filter: [plan_id: plan.id]]),
         {:ok, event_item_links} <-
           maybe_query(journal?, [], fn ->
             Journal.list_event_item_links(actor: actor, query: [filter: [plan_id: plan.id]])
           end),
         {:ok, item_effects} <-
           maybe_query(journal?, [], fn ->
             Journal.list_item_effects(actor: actor, query: [filter: [plan_id: plan.id]])
           end) do
      event_types_by_id = Map.new(event_types, &{&1.id, &1})
      item_types_by_id = Map.new(item_types, &{&1.id, &1})
      pools_by_id = Map.new(pools, &{&1.id, &1})
      session_slots_by_id = Map.new(session_slots, &{&1.id, &1})
      items_by_id = Map.new(items, &{&1.id, &1})
      slot_results_by_occurrence = Enum.group_by(slot_results, & &1.session_occurrence_id)

      slot_results_by_event_id =
        slot_results
        |> Enum.reject(&is_nil(&1.event_instance_id))
        |> Map.new(&{&1.event_instance_id, &1})

      event_item_links_by_event_id = Enum.group_by(event_item_links, & &1.event_instance_id)
      item_effects_by_event_id = Enum.group_by(item_effects, & &1.event_instance_id)
      plan_by_id = %{plan.id => plan}

      payload =
        %{}
        |> put_slice(:plans in slices, :plans, fn -> Enum.map(plans, &plan_json(&1, date)) end)
        |> put_slice(:currentPlan in slices, :currentPlan, fn ->
          plan_json(plan, date, summary)
        end)
        |> put_slice(:today in slices, :today, fn ->
          today_json(
            projection,
            plan,
            event_types_by_id,
            upcoming_work(upcoming_projections),
            slot_results_by_occurrence,
            session_slots_by_id,
            items_by_id
          )
        end)
        |> put_slice(journal?, :journal, fn ->
          journal_events
          |> Enum.take(-5)
          |> Enum.reverse()
          |> Enum.map(
            &event_json(
              &1,
              plan_by_id,
              event_types_by_id,
              event_item_links_by_event_id,
              item_effects_by_event_id,
              slot_results_by_event_id,
              session_slots_by_id,
              items_by_id
            )
          )
        end)
        |> put_slice(plan_detail?, :planDetail, fn ->
          %{
            summary: plan_json(plan, date, summary),
            items: Enum.map(items, &item_json(&1, item_types_by_id, actor)),
            itemTypes: Enum.map(item_types, &item_type_json(&1, items)),
            eventTypes: Enum.map(event_types, &event_type_json/1),
            tracks: Enum.map(tracks, &track_json(&1, event_types_by_id, schedules)),
            pools: Enum.map(pools, &pool_json/1),
            poolMemberships: Enum.map(pool_memberships, &pool_membership_json/1),
            sessionTemplates: Enum.map(session_templates, &session_template_json/1),
            sessionSlots: Enum.map(session_slots, &session_slot_json(&1, pools_by_id)),
            schedules: Enum.map(schedules, &schedule_json/1)
          }
        end)

      {:ok, payload}
    end
  end

  defp empty_dashboard,
    do: %{plans: [], currentPlan: nil, today: nil, journal: [], planDetail: nil}

  defp current_plan([], _params), do: {:error, :no_plan}

  defp current_plan(plans, %{"plan_id" => plan_id}) when is_binary(plan_id) and plan_id != "" do
    case Enum.find(plans, &(&1.id == plan_id)) do
      nil -> {:error, :no_plan}
      plan -> {:ok, plan}
    end
  end

  defp current_plan(plans, _params) do
    plan =
      Enum.find(plans, &(&1.status == :active)) ||
        Enum.find(plans, &(&1.status == :draft)) ||
        List.first(plans)

    {:ok, plan}
  end

  defp get_owned_plan(%{"plan_id" => plan_id}, actor) when is_binary(plan_id) do
    case Plans.get_plan(plan_id, actor: actor) do
      {:ok, plan} -> {:ok, plan}
      {:error, _error} -> {:error, :not_found}
    end
  end

  defp get_owned_plan(_params, _actor), do: {:error, :not_found}

  defp request_date(params), do: parse_date(Map.get(params, "date")) || Date.utc_today()

  defp create_plan_attrs(params) do
    starts_on = parse_date(Map.get(params, "starts_on")) || request_date(params)
    ends_on = parse_date(Map.get(params, "ends_on")) || Date.add(starts_on, 56)

    diagnostics =
      []
      |> maybe_add(blank?(Map.get(params, "name")), "name", "Plan name is required.")
      |> maybe_add(
        blank?(Map.get(params, "intention")),
        "intention",
        "Plan intention is required."
      )
      |> maybe_add(
        Date.compare(ends_on, starts_on) == :lt,
        "ends_on",
        "Plan end date must be after the start date."
      )

    case diagnostics do
      [] ->
        {:ok,
         %{
           name: String.trim(Map.fetch!(params, "name")),
           intention: String.trim(Map.fetch!(params, "intention")),
           starts_on: starts_on,
           ends_on: ends_on
         }}

      diagnostics ->
        {:error, diagnostics}
    end
  end

  defp persist_created_plan(attrs, actor) do
    plan =
      App.create_plan!(attrs.name,
        actor: actor,
        intention: attrs.intention,
        from: attrs.starts_on,
        until: attrs.ends_on,
        status: :draft
      )

    {:ok, plan}
  rescue
    error in [ArgumentError, Ash.Error.Invalid, Ash.Error.Forbidden] ->
      {:error, [Exception.message(error)]}
  end

  defp persist_updated_plan(plan, attrs, actor) do
    Plans.update_plan(plan, attrs, actor: actor)
  rescue
    error in [ArgumentError, Ash.Error.Invalid, Ash.Error.Forbidden] ->
      {:error, [Exception.message(error)]}
  end

  defp get_plan_resource(params, id_key, plan_id, get_fn, actor) do
    case Map.get(params, id_key) do
      id when is_binary(id) and id != "" ->
        case get_fn.(id, actor: actor) do
          {:ok, %{plan_id: ^plan_id} = resource} -> {:ok, resource}
          _other -> {:error, :not_found}
        end

      _missing ->
        {:error, :not_found}
    end
  end

  defp update_track_attrs(params) do
    attrs =
      %{}
      |> maybe_put_attr(:name, Map.get(params, "name"))
      |> maybe_put_attr(:description, Map.get(params, "description"))
      |> maybe_put_attr(:event_type_id, Map.get(params, "event_type_id"))
      |> maybe_put_attr(:target, Map.get(params, "target"))
      |> maybe_put_attr(:guidance, Map.get(params, "guidance"))

    {:ok, attrs}
  end

  defp session_template_attrs(params) do
    attrs =
      %{}
      |> maybe_put_attr(:key, Map.get(params, "key"))
      |> maybe_put_attr(:name, Map.get(params, "name"))
      |> maybe_put_attr(:description, Map.get(params, "description"))
      |> maybe_put_attr(:environment_id, Map.get(params, "environment_id"))
      |> maybe_put_attr(:completion_policy, Map.get(params, "completion_policy"))
      |> maybe_put_attr(:missed_policy, Map.get(params, "missed_policy"))

    diagnostics =
      []
      |> maybe_add(blank?(Map.get(attrs, :name, Map.get(params, "name"))), "name", "Name is required.")

    case diagnostics do
      [] -> {:ok, attrs}
      diagnostics -> {:error, diagnostics}
    end
  end

  defp session_slot_attrs(params) do
    attrs =
      %{}
      |> maybe_put_attr(:session_template_id, Map.get(params, "session_template_id"))
      |> maybe_put_attr(:key, Map.get(params, "key"))
      |> maybe_put_attr(:name, Map.get(params, "name"))
      |> maybe_put_attr(:pool_id, Map.get(params, "pool_id"))
      |> maybe_put_attr(:count, Map.get(params, "count"))
      |> maybe_put_attr(:optional, Map.get(params, "optional"))
      |> maybe_put_attr(:rules, Map.get(params, "rules"))
      |> maybe_put_attr(:position, Map.get(params, "position"))

    diagnostics =
      []
      |> maybe_add(blank?(Map.get(attrs, :name, Map.get(params, "name"))), "name", "Name is required.")

    case diagnostics do
      [] -> {:ok, attrs}
      diagnostics -> {:error, diagnostics}
    end
  end

  defp item_attrs(params) do
    attrs =
      %{}
      |> maybe_put_attr(:item_type_id, Map.get(params, "item_type_id"))
      |> maybe_put_attr(:key, Map.get(params, "key"))
      |> maybe_put_attr(:name, Map.get(params, "name"))
      |> maybe_put_attr(:facts, Map.get(params, "facts"))
      |> maybe_put_attr(:stateful, Map.get(params, "stateful"))

    diagnostics =
      []
      |> maybe_add(blank?(Map.get(attrs, :name, Map.get(params, "name"))), "name", "Name is required.")

    case diagnostics do
      [] -> {:ok, attrs}
      diagnostics -> {:error, diagnostics}
    end
  end

  defp item_type_attrs(params) do
    attrs =
      %{}
      |> maybe_put_attr(:key, Map.get(params, "key"))
      |> maybe_put_attr(:name, Map.get(params, "name"))
      |> maybe_put_attr(:description, Map.get(params, "description"))
      |> maybe_put_attr(:facts_schema, Map.get(params, "facts_schema"))
      |> maybe_put_attr(:display_hints, Map.get(params, "display_hints"))

    diagnostics =
      []
      |> maybe_add(blank?(Map.get(attrs, :name, Map.get(params, "name"))), "name", "Name is required.")

    case diagnostics do
      [] -> {:ok, attrs}
      diagnostics -> {:error, diagnostics}
    end
  end

  defp event_type_attrs(params) do
    attrs =
      %{}
      |> maybe_put_attr(:key, Map.get(params, "key"))
      |> maybe_put_attr(:name, Map.get(params, "name"))
      |> maybe_put_attr(:description, Map.get(params, "description"))
      |> maybe_put_attr(:payload_schema, Map.get(params, "payload_schema"))
      |> maybe_put_attr(:item_link_roles, Map.get(params, "item_link_roles"))
      |> maybe_put_attr(:effect_rules, Map.get(params, "effect_rules"))

    diagnostics =
      []
      |> maybe_add(blank?(Map.get(attrs, :name, Map.get(params, "name"))), "name", "Name is required.")

    case diagnostics do
      [] -> {:ok, attrs}
      diagnostics -> {:error, diagnostics}
    end
  end

  defp maybe_put_attr(map, _key, nil), do: map
  defp maybe_put_attr(map, key, value), do: Map.put(map, key, value)

  defp create_track_attrs(params) do
    quantity = blank_to_nil(Map.get(params, "quantity"))
    unit = blank_to_nil(Map.get(params, "unit"))
    target_mode = blank_to_nil(Map.get(params, "target_mode")) || "fixed"
    metric_name = blank_to_nil(Map.get(params, "metric_name"))
    event_type_id = blank_to_nil(Map.get(params, "event_type_id"))
    event_name = blank_to_nil(Map.get(params, "event_name"))

    diagnostics =
      []
      |> maybe_add(blank?(Map.get(params, "name")), "name", "Track name is required.")
      |> maybe_add(
        target_mode not in ["fixed", "metric"],
        "target_mode",
        "Choose a supported track type."
      )
      |> maybe_add(
        target_mode == "fixed" and blank?(quantity),
        "quantity",
        "Track amount is required."
      )
      |> maybe_add(
        target_mode == "metric" and blank?(metric_name),
        "metric_name",
        "Metric name is required."
      )
      |> maybe_add(blank?(unit), "unit", "Track unit is required.")
      |> maybe_add(
        blank?(event_type_id) and blank?(event_name),
        "event_type_id",
        "Choose what this track logs."
      )

    case diagnostics do
      [] ->
        {:ok,
         %{
           name: String.trim(Map.fetch!(params, "name")),
           description: blank_to_nil(Map.get(params, "description")),
           target_mode: target_mode,
           metric_name: metric_name,
           quantity: quantity,
           unit: unit,
           event_type_id: event_type_id,
           event_name: event_name
         }}

      diagnostics ->
        {:error, diagnostics}
    end
  end

  defp persist_track(plan, attrs, actor) do
    event_type =
      case attrs.event_type_id do
        nil ->
          App.add_event_type!(plan, attrs.event_name,
            actor: actor,
            key: key_from(attrs.event_name),
            payload: %{required: ["amount", "unit"]}
          )

        event_type_id ->
          Plans.get_event_type!(event_type_id, actor: actor)
      end

    track =
      App.add_track!(plan, attrs.name,
        actor: actor,
        key: key_from(attrs.name),
        description: attrs.description,
        event: event_type.key,
        schedule: App.every_day(),
        target: track_target(attrs, event_type)
      )

    {:ok, track}
  rescue
    error in [ArgumentError, Ash.Error.Invalid, Ash.Error.Forbidden] ->
      {:error, [Exception.message(error)]}
  end

  defp track_target(%{target_mode: "metric"} = attrs, event_type) do
    %{
      mode: "metric",
      metric_name: attrs.metric_name,
      unit: attrs.unit,
      quantity_path: "payload.amount",
      summary_template: "#{event_type.name} %{quantity} %{unit}"
    }
  end

  defp track_target(attrs, event_type) do
    %{
      mode: "fixed",
      quantity: attrs.quantity,
      unit: attrs.unit,
      quantity_path: "payload.amount",
      summary_template: "#{event_type.name} %{quantity} %{unit}"
    }
  end

  defp get_plan_item(params, plan_id, actor) do
    item_id = blank_to_nil(Map.get(params, "item_id"))
    item_key = blank_to_nil(Map.get(params, "item_key"))

    cond do
      item_id ->
        case Plans.get_item(item_id, actor: actor) do
          {:ok, %{plan_id: ^plan_id} = item} -> {:ok, item}
          _other -> {:error, :not_found}
        end

      item_key ->
        plan_id
        |> items_by_key(actor)
        |> Map.get(item_key)
        |> case do
          nil -> {:error, :not_found}
          item -> {:ok, item}
        end

      true ->
        {:error, :not_found}
    end
  end

  defp get_plan_event_type(%{"event_type_id" => id}, plan_id, actor) when is_binary(id) do
    case Plans.get_event_type(id, actor: actor) do
      {:ok, %{plan_id: ^plan_id} = event_type} -> {:ok, event_type}
      _other -> {:error, :not_found}
    end
  end

  defp get_plan_event_type(%{"event_key" => key}, plan_id, actor) when is_binary(key) do
    with {:ok, event_types} <-
           Plans.list_event_types(actor: actor, query: [filter: [plan_id: plan_id]]) do
      event_types
      |> Enum.find(&(&1.key == key))
      |> case do
        nil -> {:error, :not_found}
        event_type -> {:ok, event_type}
      end
    end
  end

  defp get_plan_event_type(_params, _plan_id, _actor), do: {:error, :not_found}

  defp get_event(%{"original_event_id" => id}, actor) when is_binary(id) do
    case Journal.get_event(id, actor: actor) do
      {:ok, event} -> {:ok, event}
      {:error, _error} -> {:error, :not_found}
    end
  end

  defp get_event(_params, _actor), do: {:error, :not_found}

  defp ensure_event_plan(%{plan_id: plan_id}, %{id: plan_id}), do: :ok
  defp ensure_event_plan(_event, _plan), do: {:error, :not_found}

  defp get_active_effect(original_event, linked_item, actor) do
    with {:ok, effects} <-
           Journal.list_item_effects(
             actor: actor,
             query: [
               filter: [
                 event_instance_id: original_event.id,
                 item_id: linked_item.id,
                 status: :active
               ]
             ]
           ) do
      case effects do
        [effect | _rest] -> {:ok, effect}
        [] -> {:error, :not_found}
      end
    end
  end

  defp log_linked_event(plan, linked_item, event_type, params, actor) do
    now = DateTime.utc_now()

    attrs =
      params
      |> linked_event_attrs(plan, linked_item, event_type, now)
      |> Map.put(:summary, event_summary(params, "#{event_type.name} for #{linked_item.name}"))

    {:ok, Journal.log_linked_item_event!(attrs, actor: actor)}
  rescue
    error in [KeyError, ArgumentError, Ash.Error.Invalid, Ash.Error.Forbidden] ->
      {:error, [Exception.message(error)]}
  end

  defp correct_linked_event(
         plan,
         linked_item,
         event_type,
         original_event,
         original_effect,
         params,
         actor
       ) do
    now = DateTime.utc_now()

    attrs =
      params
      |> linked_event_attrs(plan, linked_item, event_type, now)
      |> Map.merge(%{
        original_event: original_event,
        original_effect: original_effect,
        corrected_at: now,
        correction_note:
          blank_to_nil(Map.get(params, "correction_note")) || "Corrected by replacement event",
        summary: event_summary(params, "Corrected #{event_type.name} for #{linked_item.name}")
      })

    {:ok, Journal.correct_linked_item_event!(attrs, actor: actor)}
  rescue
    error in [KeyError, ArgumentError, Ash.Error.Invalid, Ash.Error.Forbidden] ->
      {:error, [Exception.message(error)]}
  end

  defp linked_event_attrs(params, plan, linked_item, event_type, now) do
    %{
      plan: plan,
      event_type: event_type,
      linked_item: linked_item,
      role: Map.fetch!(params, "role"),
      effective_at: parse_datetime(Map.get(params, "effective_at")) || now,
      recorded_at: now,
      quantity: Map.fetch!(params, "quantity"),
      unit: Map.fetch!(params, "unit"),
      payload:
        payload_with_quantity(
          Map.get(params, "payload", %{}),
          Map.fetch!(params, "quantity"),
          Map.fetch!(params, "unit"),
          blank_to_nil(Map.get(params, "note"))
        ),
      note: blank_to_nil(Map.get(params, "note")),
      idempotency: idempotency_from_params(params)
    }
  end

  defp event_summary(params, default) do
    blank_to_nil(Map.get(params, "summary")) || default
  end

  defp get_projected_session_template(params, projection, actor) do
    template_id = Map.get(params, "session_template_id")

    with projected_occurrence when not is_nil(projected_occurrence) <-
           Enum.find(
             projection.projected_session_occurrences,
             &(&1.session_template_id == template_id)
           ),
         {:ok, template} <- Plans.get_session_template(template_id, actor: actor) do
      {:ok, template}
    else
      _other -> {:error, :not_found}
    end
  end

  defp maybe_start_projected_session(projection, template, actor) do
    projection.projected_session_occurrences
    |> Enum.find(&(&1.session_template_id == template.id))
    |> case do
      %{session_state: %{session_occurrence_id: id}} when not is_nil(id) ->
        :ok

      _projected_occurrence ->
        App.start_session!(projection, template.key, actor: actor, started_at: DateTime.utc_now())
        :ok
    end
  rescue
    _error in [ArgumentError, Ash.Error.Invalid, Ash.Error.Forbidden] ->
      {:error, :start_failed}
  end

  defp get_session_occurrence(%{"session_occurrence_id" => id}, actor) when is_binary(id) do
    case Sessions.get_session_occurrence(id, actor: actor) do
      {:ok, occurrence} -> {:ok, occurrence}
      {:error, _error} -> {:error, :not_found}
    end
  end

  defp get_session_occurrence(_params, _actor), do: {:error, :not_found}

  defp get_slot_result(%{"slot_result_id" => id}, actor) when is_binary(id) do
    case Sessions.get_slot_result(id, actor: actor) do
      {:ok, slot_result} -> {:ok, slot_result}
      {:error, _error} -> {:error, :not_found}
    end
  end

  defp get_slot_result(_params, _actor), do: {:error, :not_found}

  defp get_slot_actual_item(%{"actual_item_key" => key}, plan_id, actor) when is_binary(key) do
    plan_id
    |> items_by_key(actor)
    |> Map.get(key)
    |> case do
      nil -> {:error, :not_found}
      item -> {:ok, item}
    end
  end

  defp get_slot_actual_item(_params, _plan_id, _actor), do: {:error, :not_found}

  defp items_by_key(plan_id, actor) do
    actor
    |> Improve.App.Lookup.items(plan_id)
    |> Map.new(&{&1.key, &1})
  end

  defp started_session(occurrence, actor) do
    with {:ok, slot_results} <-
           Sessions.list_slot_results(
             actor: actor,
             query: [filter: [session_occurrence_id: occurrence.id]]
           ) do
      {:ok, %{session_occurrence: occurrence, slot_results: slot_results}}
    end
  end

  defp log_session_slot_event(started_session, params, actor) do
    opts =
      [
        actor: actor,
        slot: Map.get(params, "slot_key"),
        item: Map.get(params, "actual_item_key"),
        recommended: blank_to_nil(Map.get(params, "recommended_item_key")),
        event: Map.get(params, "event_key"),
        role: Map.get(params, "role"),
        payload: Map.get(params, "payload", %{})
      ]
      |> maybe_put_keyword(:quantity, blank_to_nil(Map.get(params, "quantity")))
      |> maybe_put_keyword(:unit, blank_to_nil(Map.get(params, "unit")))
      |> maybe_put_keyword(:note, blank_to_nil(Map.get(params, "note")))
      |> maybe_put_keyword(:summary, blank_to_nil(Map.get(params, "summary")))
      |> maybe_put_keyword(:idempotency, idempotency_from_params(params))

    result = App.log_session_slot!(started_session, opts)

    {:ok, result}
  rescue
    error in [ArgumentError, Ash.Error.Invalid, Ash.Error.Forbidden] ->
      {:error, [Exception.message(error)]}
  end

  defp swap_slot_result(slot_result, item, params, actor) do
    try do
      {:ok,
       Sessions.swap_slot_result!(
         slot_result,
         %{
           actual_item_id: item.id,
           actual_payload: Map.get(params, "payload", %{}),
           notes: blank_to_nil(Map.get(params, "note"))
         },
         actor: actor
       )}
    rescue
      error in [ArgumentError, Ash.Error.Invalid, Ash.Error.Forbidden] ->
        {:error, [Exception.message(error)]}
    end
  end

  defp update_session_status(actor, params, action) do
    with {:ok, occurrence} <- get_session_occurrence(params, actor),
         {:ok, _occurrence} <- apply_session_status(occurrence, action, params, actor),
         {:ok, plan} <- Plans.get_plan(occurrence.plan_id, actor: actor),
         {:ok, payload} <- mutation_payload(plan, actor, params, [:today, :journal]) do
      {:ok, payload}
    else
      {:error, diagnostics} when is_list(diagnostics) ->
        {:error, diagnostics}

      {:error, error} ->
        {:error, error}
    end
  end

  defp apply_session_status(occurrence, :complete, params, actor) do
    try do
      {:ok,
       Sessions.complete_session_occurrence!(
         occurrence,
         %{
           completed_at: DateTime.utc_now(),
           notes: blank_to_nil(Map.get(params, "note"))
         },
         actor: actor
       )}
    rescue
      error in [ArgumentError, Ash.Error.Invalid, Ash.Error.Forbidden] ->
        {:error, [Exception.message(error)]}
    end
  end

  defp apply_session_status(occurrence, :skip, params, actor) do
    try do
      {:ok,
       Sessions.mark_session_occurrence_skipped!(
         occurrence,
         %{notes: blank_to_nil(Map.get(params, "note"))},
         actor: actor
       )}
    rescue
      error in [ArgumentError, Ash.Error.Invalid, Ash.Error.Forbidden] ->
        {:error, [Exception.message(error)]}
    end
  end

  defp install_or_select_demo_plan(actor, kind) do
    with {:ok, source_key, installer} <- DemoPlans.fetch(kind),
         {:ok, plans} <- Plans.list_plans(actor: actor) do
      case Enum.find(plans, &(&1.source_kind == :demo and &1.source_key == source_key)) do
        nil -> install_demo_plan_with(actor, installer)
        plan -> {:ok, plan}
      end
    end
  end

  defp install_demo_plan_with(actor, installer) do
    result = installer.(actor, starts_on: Date.utc_today())
    {:ok, Map.fetch!(result, :plan)}
  rescue
    _error in [ArgumentError, Ash.Error.Invalid, Ash.Error.Forbidden] ->
      {:error, :install_failed}
  end

  defp upcoming_work(projections), do: Enum.flat_map(projections, & &1.projected_work)

  defp next_days(date, count) do
    Enum.map(1..count, &Date.add(date, &1))
  end

  defp today_json(
         projection,
         plan,
         event_types_by_id,
         upcoming,
         slot_results_by_occurrence,
         session_slots_by_id,
         items_by_id
       ) do
    work =
      Enum.map(
        projection.projected_work,
        &work_json(
          &1,
          plan,
          event_types_by_id,
          slot_results_by_occurrence,
          session_slots_by_id,
          items_by_id
        )
      )

    completed = Enum.count(work, &(&1.status == "completed"))

    %{
      planId: projection.plan_id,
      date: Date.to_iso8601(projection.date),
      total: length(work),
      completed: completed,
      remaining: max(length(work) - completed, 0),
      work: work,
      upcoming:
        upcoming
        |> Enum.take(5)
        |> Enum.map(
          &work_json(
            &1,
            plan,
            event_types_by_id,
            slot_results_by_occurrence,
            session_slots_by_id,
            items_by_id
          )
        ),
      diagnostics: camelize_keys(projection.diagnostics),
      explanations: camelize_keys(projection.explanations)
    }
  end

  defp work_json(
         work,
         plan,
         event_types_by_id,
         slot_results_by_occurrence,
         session_slots_by_id,
         items_by_id
       ) do
    payload = work.payload
    event_type_id = Map.get(payload, :event_type_id)
    target = Map.get(payload, :target, %{})
    event_type = Map.get(event_types_by_id, event_type_id)

    %{
      id: "#{work.kind}:#{work.owner_id}:#{Date.to_iso8601(work.planned_for)}",
      kind: Atom.to_string(work.kind),
      status: Atom.to_string(work.status),
      plannedFor: Date.to_iso8601(work.planned_for),
      ownerType: Atom.to_string(work.owner_type),
      ownerId: work.owner_id,
      title: work.title,
      planId: work.plan_id,
      planName: plan.name,
      explanation: work.explanation,
      target: target_json(target),
      targetProgress: payload |> Map.get(:target_progress, %{}) |> camelize_keys(),
      eventTypeId: event_type_id,
      eventTypeName: event_type && event_type.name,
      trackId: Map.get(payload, :track_id),
      trackKey: Map.get(payload, :track_key),
      session:
        session_work_json(
          work,
          slot_results_by_occurrence,
          session_slots_by_id,
          items_by_id
        ),
      canLog:
        work.kind == :track and work.status not in [:completed, :on_hold] and
          not is_nil(event_type_id)
    }
  end

  defp session_work_json(
         %{kind: :session, payload: %{session_occurrence: occurrence}},
         slot_results_by_occurrence,
         session_slots_by_id,
         items_by_id
       ) do
    occurrence_id = Map.get(occurrence.session_state, :session_occurrence_id)

    slot_results =
      if occurrence_id, do: Map.get(slot_results_by_occurrence, occurrence_id, []), else: []

    %{
      sessionTemplateId: occurrence.session_template_id,
      recommendations:
        occurrence.recommendations
        |> Enum.flat_map(& &1.recommended_items)
        |> Enum.map(fn item ->
          %{
            id: item.item_id,
            key: item.item_key,
            name: item.item_name,
            reason: Map.get(item, :reason),
            source: Map.get(item, :source),
            suggestedPayload: Map.get(item, :suggested_payload, %{}),
            previousEventIds: Map.get(item, :previous_event_ids, []),
            previousEvents: Map.get(item, :previous_events, [])
          }
        end),
      state: occurrence |> Map.get(:session_state, %{}) |> camelize_keys(),
      slotResults:
        Enum.map(
          slot_results,
          &slot_result_json(&1, session_slots_by_id, items_by_id)
        )
    }
  end

  defp session_work_json(_work, _slot_results_by_occurrence, _session_slots_by_id, _items_by_id),
    do: nil

  defp slot_result_json(slot_result, session_slots_by_id, items_by_id) do
    slot = Map.get(session_slots_by_id, slot_result.session_slot_id)

    recommended_item =
      slot_result.recommended_item_id && Map.get(items_by_id, slot_result.recommended_item_id)

    actual_item = slot_result.actual_item_id && Map.get(items_by_id, slot_result.actual_item_id)

    %{
      id: slot_result.id,
      status: Atom.to_string(slot_result.status),
      sessionOccurrenceId: slot_result.session_occurrence_id,
      sessionSlotId: slot_result.session_slot_id,
      slotKey: slot && slot.key,
      slotName: slot && slot.name,
      poolId: slot && slot.pool_id,
      poolName: slot && Map.get(slot, :poolName),
      recommendedItemId: slot_result.recommended_item_id,
      recommendedItemKey: recommended_item && recommended_item.key,
      recommendedItemName: recommended_item && recommended_item.name,
      actualItemId: slot_result.actual_item_id,
      actualItemKey: actual_item && actual_item.key,
      actualItemName: actual_item && actual_item.name,
      suggestedPayload: slot_result.suggested_payload,
      actualPayload: slot_result.actual_payload,
      eventInstanceId: slot_result.event_instance_id,
      notes: slot_result.notes
    }
  end

  defp target_json(target) when is_map(target) do
    %{
      quantity: map_value(target, "quantity"),
      unit: map_value(target, "unit"),
      mode: map_value(target, "mode"),
      metricName: map_value(target, "metric_name"),
      quantityPath: map_value(target, "quantity_path"),
      summaryTemplate: map_value(target, "summary_template")
    }
  end

  defp target_json(_target), do: %{}

  defp plan_json(plan, date, summary \\ nil) do
    duration = Date.diff(plan.ends_on, plan.starts_on) + 1
    elapsed = Date.diff(date, plan.starts_on) + 1

    %{
      id: plan.id,
      name: plan.name,
      intention: plan.intention,
      startsOn: Date.to_iso8601(plan.starts_on),
      endsOn: Date.to_iso8601(plan.ends_on),
      status: Atom.to_string(plan.status),
      sourceKind: Atom.to_string(plan.source_kind),
      sourceKey: plan.source_key,
      dayLabel: day_label(elapsed, duration),
      summary: summary && camelize_keys(summary)
    }
  end

  defp day_label(elapsed, duration) when elapsed >= 1 and elapsed <= duration do
    "Day #{elapsed} of #{duration}"
  end

  defp day_label(_elapsed, duration), do: "#{duration} day plan"

  defp item_json(item, item_types_by_id, actor) do
    item_type = Map.get(item_types_by_id, item.item_type_id)

    %{
      id: item.id,
      key: item.key,
      name: item.name,
      typeId: item.item_type_id,
      typeKey: item_type && item_type.key,
      stateful: item.stateful,
      state: item_state_json(item, actor),
      facts: item.facts,
      archived: not is_nil(item.archived_at)
    }
  end

  defp item_state_json(%{stateful: true} = item, actor) do
    state = Journal.get_item_state!(item, actor: actor)

    %{
      itemId: state.item_id,
      startingFacts: stringify_values(state.starting_facts),
      calculatedState: stringify_values(state.calculated_state),
      activeEffects: Enum.map(state.active_effects, &item_effect_json(&1, %{})),
      warnings: camelize_keys(state.warnings)
    }
  end

  defp item_state_json(_item, _actor), do: nil

  defp item_type_json(item_type, items) do
    %{
      id: item_type.id,
      key: item_type.key,
      name: item_type.name,
      description: item_type.description,
      factsSchema: item_type.facts_schema,
      displayHints: item_type.display_hints,
      itemCount: Enum.count(items, &(&1.item_type_id == item_type.id))
    }
  end

  defp event_type_json(event_type) do
    %{
      id: event_type.id,
      key: event_type.key,
      name: event_type.name,
      description: event_type.description,
      payloadSchema: event_type.payload_schema,
      itemLinkRoles: event_type.item_link_roles,
      effectRules: event_type.effect_rules
    }
  end

  defp track_json(track, event_types_by_id, schedules) do
    event_type = Map.get(event_types_by_id, track.event_type_id)

    schedule =
      Enum.find(schedules, &(&1.owner_type == :track and &1.owner_id == track.id))

    %{
      id: track.id,
      key: track.key,
      name: track.name,
      description: track.description,
      eventTypeId: track.event_type_id,
      eventTypeName: event_type && event_type.name,
      target: target_json(track.target),
      schedule: schedule && schedule_json(schedule)
    }
  end

  defp pool_json(pool) do
    %{
      id: pool.id,
      key: pool.key,
      name: pool.name,
      description: pool.description
    }
  end

  defp pool_membership_json(pool_membership) do
    %{
      id: pool_membership.id,
      poolId: pool_membership.pool_id,
      itemId: pool_membership.item_id,
      metadata: pool_membership.metadata
    }
  end

  defp session_template_json(session_template) do
    %{
      id: session_template.id,
      key: session_template.key,
      name: session_template.name,
      description: session_template.description,
      environmentId: session_template.environment_id,
      completionPolicy: session_template.completion_policy,
      missedPolicy: session_template.missed_policy
    }
  end

  defp session_slot_json(session_slot, pools_by_id) do
    pool = Map.get(pools_by_id, session_slot.pool_id)

    %{
      id: session_slot.id,
      sessionTemplateId: session_slot.session_template_id,
      key: session_slot.key,
      name: session_slot.name,
      poolId: session_slot.pool_id,
      poolName: pool && pool.name,
      count: session_slot.count,
      optional: session_slot.optional,
      rules: session_slot.rules,
      position: session_slot.position
    }
  end

  defp schedule_json(schedule) do
    %{
      id: schedule.id,
      ownerType: Atom.to_string(schedule.owner_type),
      ownerId: schedule.owner_id,
      kind: Atom.to_string(schedule.kind),
      rules: schedule.rules,
      startsOn: Date.to_iso8601(schedule.starts_on),
      endsOn: schedule.ends_on && Date.to_iso8601(schedule.ends_on)
    }
  end

  defp event_json(
         event,
         plans_by_id,
         event_types_by_id,
         event_item_links_by_event_id \\ %{},
         item_effects_by_event_id \\ %{},
         slot_results_by_event_id \\ %{},
         session_slots_by_id \\ %{},
         items_by_id \\ %{}
       ) do
    plan = plans_by_id && Map.get(plans_by_id, event.plan_id)
    event_type = event_types_by_id && Map.get(event_types_by_id, event.event_type_id)
    slot_result = Map.get(slot_results_by_event_id, event.id)
    slot = slot_result && Map.get(session_slots_by_id, slot_result.session_slot_id)

    %{
      id: event.id,
      planId: event.plan_id,
      planName: plan && plan.name,
      eventTypeId: event.event_type_id,
      eventTypeName: event_type && event_type.name,
      summary: event.summary,
      quantity: decimal_string(event.quantity),
      unit: event.unit,
      note: event.note,
      status: Atom.to_string(event.status),
      effectiveAt: DateTime.to_iso8601(event.effective_at),
      recordedAt: DateTime.to_iso8601(event.recorded_at),
      sessionOccurrenceId: event.session_occurrence_id,
      slotResultId: event.slot_result_id,
      trackId: event.track_id,
      slot:
        if(slot_result,
          do: %{
            id: slot_result.id,
            status: Atom.to_string(slot_result.status),
            slotKey: slot && slot.key,
            slotName: slot && slot.name
          }
        ),
      itemLinks:
        event_item_links_by_event_id
        |> Map.get(event.id, [])
        |> Enum.map(&event_item_link_json(&1, items_by_id)),
      itemEffects:
        item_effects_by_event_id
        |> Map.get(event.id, [])
        |> Enum.map(&item_effect_json(&1, items_by_id))
    }
  end

  defp event_item_link_json(link, items_by_id) do
    item = Map.get(items_by_id, link.item_id)

    %{
      id: link.id,
      role: link.role,
      itemId: link.item_id,
      itemKey: item && item.key,
      itemName: item && item.name,
      metadata: link.metadata
    }
  end

  defp item_effect_json(effect, items_by_id) do
    item = Map.get(items_by_id, effect.item_id)

    %{
      id: effect.id,
      itemId: effect.item_id,
      itemKey: item && item.key,
      itemName: item && item.name,
      effectType: Atom.to_string(effect.effect_type),
      quantity: decimal_string(effect.quantity),
      unit: effect.unit,
      status: Atom.to_string(effect.status),
      eventInstanceId: effect.event_instance_id,
      replacesItemEffectId: effect.replaces_item_effect_id
    }
  end

  # Engine-produced maps use snake_case keys internally; the API speaks
  # camelCase. Never applied to user-authored JSONB (facts, payloads, rules,
  # schemas) — those keys belong to the user.
  defp camelize_keys(map) when is_map(map) and not is_struct(map) do
    Map.new(map, fn {key, value} -> {camel_key(key), camelize_keys(value)} end)
  end

  defp camelize_keys(list) when is_list(list), do: Enum.map(list, &camelize_keys/1)
  defp camelize_keys(value), do: value

  defp camel_key(key) when is_atom(key), do: key |> Atom.to_string() |> camel_key()

  defp camel_key(key) when is_binary(key) do
    [head | rest] = String.split(key, "_")
    head <> Enum.map_join(rest, "", &String.capitalize/1)
  end

  defp camel_key(key), do: key

  defp stringify_values(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {key, stringify_value(value)} end)
  end

  defp stringify_value(%Decimal{} = value), do: Decimal.to_string(value)
  defp stringify_value(value), do: value

  defp log_attrs(params) do
    now = DateTime.utc_now()
    quantity = blank_to_nil(Map.get(params, "quantity"))
    unit = blank_to_nil(Map.get(params, "unit"))
    note = blank_to_nil(Map.get(params, "note"))
    payload = payload_with_quantity(Map.get(params, "payload", %{}), quantity, unit, note)

    attrs = %{
      plan_id: Map.get(params, "plan_id"),
      event_type_id: Map.get(params, "event_type_id"),
      track_id: blank_to_nil(Map.get(params, "track_id")),
      effective_at: parse_datetime(Map.get(params, "effective_at")) || now,
      recorded_at: now,
      summary: blank_to_nil(Map.get(params, "summary")) || "Logged event",
      quantity: quantity,
      unit: unit,
      note: note,
      payload: payload,
      item_links: item_links(Map.get(params, "item_links", [])),
      idempotency: idempotency_from_params(params)
    }

    {:ok, attrs}
  end

  defp idempotency_from_params(params) do
    attrs = %{
      client_event_id: blank_to_nil(Map.get(params, "client_event_id")),
      client_operation_id: blank_to_nil(Map.get(params, "client_operation_id")),
      client_device_id: blank_to_nil(Map.get(params, "client_device_id")),
      idempotency_key: blank_to_nil(Map.get(params, "idempotency_key"))
    }

    if attrs.client_operation_id || attrs.idempotency_key || attrs.client_device_id do
      attrs
    else
      nil
    end
  end

  defp item_links(item_links) when is_list(item_links) do
    Enum.map(item_links, fn
      item_link when is_map(item_link) ->
        %{
          role: map_value(item_link, "role"),
          item_id: map_value(item_link, "item_id"),
          metadata: map_value(item_link, "metadata") || %{}
        }

      other ->
        other
    end)
  end

  defp item_links(_item_links), do: []

  defp payload_with_quantity(payload, quantity, unit, note) when is_map(payload) do
    payload
    |> maybe_put("amount", quantity)
    |> maybe_put("unit", unit)
    |> maybe_put("note", note)
  end

  defp payload_with_quantity(_payload, quantity, unit, note) do
    payload_with_quantity(%{}, quantity, unit, note)
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      _other -> nil
    end
  end

  defp parse_date(nil), do: nil

  defp parse_date(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _other -> nil
    end
  end

  defp map_value(map, key) do
    cond do
      Map.has_key?(map, key) ->
        Map.fetch!(map, key)

      Map.has_key?(map, String.to_existing_atom(key)) ->
        Map.get(map, String.to_existing_atom(key))

      true ->
        nil
    end
  rescue
    ArgumentError -> nil
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp key_from(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "_")
    |> String.trim("_")
    |> case do
      "" -> "item"
      key -> key
    end
  end

  defp blank?(nil), do: true
  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(_value), do: false

  defp maybe_add(diagnostics, true, field, message),
    do: diagnostics ++ [%{field: field, message: message}]

  defp maybe_add(diagnostics, false, _field, _message), do: diagnostics

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_keyword(keyword, _key, nil), do: keyword
  defp maybe_put_keyword(keyword, _key, ""), do: keyword
  defp maybe_put_keyword(keyword, key, value), do: Keyword.put(keyword, key, value)

  defp decimal_string(nil), do: nil
  defp decimal_string(%Decimal{} = value), do: Decimal.to_string(value)
  defp decimal_string(value), do: to_string(value)
end
