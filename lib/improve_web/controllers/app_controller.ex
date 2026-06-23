defmodule ImproveWeb.AppController do
  use ImproveWeb, :controller

  alias Improve.Journal
  alias Improve.App
  alias Improve.Plans
  alias Improve.Sessions
  alias Improve.Fixtures.GymPlan
  alias Improve.Fixtures.VialPlan

  def dashboard(conn, params) do
    with {:ok, actor} <- current_actor(conn),
         {:ok, plans} <- Plans.list_plans(actor: actor),
         {:ok, plan} <- current_plan(plans, params),
         {:ok, payload} <- dashboard_payload(plan, plans, actor, params) do
      json(conn, payload)
    else
      {:error, :unauthenticated} ->
        app_error(conn, 401, "Please sign in to continue.")

      {:error, :no_plan} ->
        json(conn, %{plans: [], currentPlan: nil, today: nil, journal: [], planDetail: nil})

      {:error, _error} ->
        app_error(conn, 400, "We could not load your planning dashboard.")
    end
  end

  def log_event(conn, params) do
    with {:ok, actor} <- current_actor(conn),
         {:ok, attrs} <- log_attrs(params),
         {:ok, result} <- Journal.log_generic_event(attrs, actor: actor) do
      json(conn, %{event: event_json(result.event, nil, nil)})
    else
      {:error, :unauthenticated} ->
        app_error(conn, 401, "Please sign in to continue.")

      {:error, diagnostics} when is_list(diagnostics) ->
        app_error(conn, 422, Enum.join(diagnostics, " "))

      {:error, _error} ->
        app_error(conn, 422, "We could not log that event.")
    end
  end

  def install_demo_plan(conn, params) do
    with {:ok, actor} <- current_actor(conn),
         {:ok, plan} <- install_or_select_demo_plan(actor, Map.get(params, "kind")),
         {:ok, plans} <- Plans.list_plans(actor: actor),
         {:ok, payload} <- dashboard_payload(plan, plans, actor, params) do
      json(conn, payload)
    else
      {:error, :unauthenticated} ->
        app_error(conn, 401, "Please sign in to continue.")

      {:error, :unknown_demo_plan} ->
        app_error(conn, 422, "Choose a demo plan to install.")

      {:error, _error} ->
        app_error(conn, 422, "We could not install that demo plan.")
    end
  end

  def start_session(conn, params) do
    with {:ok, actor} <- current_actor(conn),
         {:ok, plan} <- get_owned_plan(params, actor),
         {:ok, projection} <- Plans.project_today(plan, actor: actor, date: request_date(params)),
         {:ok, template} <- get_projected_session_template(params, projection, actor),
         :ok <- maybe_start_projected_session(projection, template, actor),
         {:ok, plans} <- Plans.list_plans(actor: actor),
         {:ok, payload} <- dashboard_payload(plan, plans, actor, params) do
      json(conn, payload)
    else
      {:error, :unauthenticated} ->
        app_error(conn, 401, "Please sign in to continue.")

      {:error, :not_found} ->
        app_error(conn, 404, "That projected session is not available.")

      {:error, _error} ->
        app_error(conn, 422, "We could not start that session.")
    end
  end

  def log_session_slot(conn, params) do
    with {:ok, actor} <- current_actor(conn),
         {:ok, occurrence} <- get_session_occurrence(params, actor),
         {:ok, started_session} <- started_session(occurrence, actor),
         {:ok, _result} <- log_session_slot_event(started_session, params, actor),
         {:ok, plan} <- Plans.get_plan(occurrence.plan_id, actor: actor),
         {:ok, plans} <- Plans.list_plans(actor: actor),
         {:ok, payload} <- dashboard_payload(plan, plans, actor, params) do
      json(conn, payload)
    else
      {:error, :unauthenticated} ->
        app_error(conn, 401, "Please sign in to continue.")

      {:error, :not_found} ->
        app_error(conn, 404, "That session slot is not available.")

      {:error, diagnostics} when is_list(diagnostics) ->
        app_error(conn, 422, Enum.join(diagnostics, " "))

      {:error, _error} ->
        app_error(conn, 422, "We could not log that session slot.")
    end
  end

  def swap_session_slot(conn, params) do
    with {:ok, actor} <- current_actor(conn),
         {:ok, slot_result} <- get_slot_result(params, actor),
         {:ok, item} <- get_slot_actual_item(params, slot_result.plan_id, actor),
         {:ok, _slot_result} <- swap_slot_result(slot_result, item, params, actor),
         {:ok, plan} <- Plans.get_plan(slot_result.plan_id, actor: actor),
         {:ok, plans} <- Plans.list_plans(actor: actor),
         {:ok, payload} <- dashboard_payload(plan, plans, actor, params) do
      json(conn, payload)
    else
      {:error, :unauthenticated} ->
        app_error(conn, 401, "Please sign in to continue.")

      {:error, :not_found} ->
        app_error(conn, 404, "That session slot is not available.")

      {:error, diagnostics} when is_list(diagnostics) ->
        app_error(conn, 422, Enum.join(diagnostics, " "))

      {:error, _error} ->
        app_error(conn, 422, "We could not swap that session slot.")
    end
  end

  def complete_session(conn, params) do
    update_session_status(conn, params, :complete)
  end

  def skip_session(conn, params) do
    update_session_status(conn, params, :skip)
  end

  defp dashboard_payload(plan, plans, actor, params) do
    date = parse_date(Map.get(params, "date")) || Date.utc_today()

    with {:ok, summary} <- Plans.summarize_plan(plan, actor: actor),
         {:ok, projection} <- Plans.project_today(plan, actor: actor, date: date),
         {:ok, journal_events} <- Journal.read_journal(plan, actor: actor),
         {:ok, items} <- Plans.list_items(actor: actor, query: [filter: [plan_id: plan.id]]),
         {:ok, item_types} <-
           Plans.list_item_types(actor: actor, query: [filter: [plan_id: plan.id]]),
         {:ok, event_types} <-
           Plans.list_event_types(actor: actor, query: [filter: [plan_id: plan.id]]),
         {:ok, pools} <- Plans.list_pools(actor: actor, query: [filter: [plan_id: plan.id]]),
         {:ok, pool_memberships} <-
           Plans.list_pool_memberships(actor: actor, query: [filter: [plan_id: plan.id]]),
         {:ok, session_templates} <-
           Plans.list_session_templates(actor: actor, query: [filter: [plan_id: plan.id]]),
         {:ok, session_slots} <-
           Plans.list_session_slots(actor: actor, query: [filter: [plan_id: plan.id]]),
         {:ok, schedules} <-
           Plans.list_schedules(actor: actor, query: [filter: [plan_id: plan.id]]),
         {:ok, slot_results} <-
           Sessions.list_slot_results(actor: actor, query: [filter: [plan_id: plan.id]]),
         {:ok, event_item_links} <-
           Journal.list_event_item_links(actor: actor, query: [filter: [plan_id: plan.id]]),
         {:ok, item_effects} <-
           Journal.list_item_effects(actor: actor, query: [filter: [plan_id: plan.id]]),
         {:ok, upcoming} <- upcoming_work(plan, actor, date) do
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
      plan_by_id = Map.new(plans, &{&1.id, &1})

      {:ok,
       %{
         plans: Enum.map(plans, &plan_json/1),
         currentPlan: plan_json(plan, summary),
         today:
           today_json(
             projection,
             plan,
             event_types_by_id,
             upcoming,
             slot_results_by_occurrence,
             session_slots_by_id,
             items_by_id
           ),
         journal:
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
           ),
         planDetail: %{
           summary: plan_json(plan, summary),
           items: Enum.map(items, &item_json(&1, item_types_by_id)),
           itemTypes: Enum.map(item_types, &item_type_json(&1, items)),
           eventTypes: Enum.map(event_types, &event_type_json/1),
           pools: Enum.map(pools, &pool_json/1),
           poolMemberships: Enum.map(pool_memberships, &pool_membership_json/1),
           sessionTemplates: Enum.map(session_templates, &session_template_json/1),
           sessionSlots: Enum.map(session_slots, &session_slot_json(&1, pools_by_id)),
           schedules: Enum.map(schedules, &schedule_json/1)
         }
       }}
    end
  end

  defp current_actor(%{assigns: %{current_user: actor}}) when not is_nil(actor), do: {:ok, actor}
  defp current_actor(_conn), do: {:error, :unauthenticated}

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
    _error -> {:error, :start_failed}
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

    result = App.log_session_slot!(started_session, opts)

    {:ok, result}
  rescue
    error in [ArgumentError, Ash.Error.Invalid, Ash.Error.Forbidden] ->
      {:error, [Exception.message(error)]}

    error ->
      {:error, [Exception.message(error)]}
  end

  defp swap_slot_result(slot_result, item, params, actor) do
    try do
      {:ok,
       Sessions.swap_slot_result!(
         slot_result,
         %{
           actual_item_id: item.id,
           notes: blank_to_nil(Map.get(params, "note"))
         },
         actor: actor
       )}
    rescue
      error in [ArgumentError, Ash.Error.Invalid, Ash.Error.Forbidden] ->
        {:error, [Exception.message(error)]}

      error ->
        {:error, [Exception.message(error)]}
    end
  end

  defp update_session_status(conn, params, action) do
    with {:ok, actor} <- current_actor(conn),
         {:ok, occurrence} <- get_session_occurrence(params, actor),
         {:ok, _occurrence} <- apply_session_status(occurrence, action, params, actor),
         {:ok, plan} <- Plans.get_plan(occurrence.plan_id, actor: actor),
         {:ok, plans} <- Plans.list_plans(actor: actor),
         {:ok, payload} <- dashboard_payload(plan, plans, actor, params) do
      json(conn, payload)
    else
      {:error, :unauthenticated} ->
        app_error(conn, 401, "Please sign in to continue.")

      {:error, :not_found} ->
        app_error(conn, 404, "That session is not available.")

      {:error, diagnostics} when is_list(diagnostics) ->
        app_error(conn, 422, Enum.join(diagnostics, " "))

      {:error, _error} ->
        app_error(conn, 422, "We could not update that session.")
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

      error ->
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

      error ->
        {:error, [Exception.message(error)]}
    end
  end

  defp install_or_select_demo_plan(actor, kind) do
    with {:ok, source_key, installer} <- demo_plan(kind),
         {:ok, plans} <- Plans.list_plans(actor: actor) do
      case Enum.find(plans, &(&1.source_kind == :demo and &1.source_key == source_key)) do
        nil -> install_demo_plan_with(actor, installer)
        plan -> {:ok, plan}
      end
    end
  end

  defp demo_plan("gym"), do: {:ok, "gym", &GymPlan.install!/2}
  defp demo_plan("vial_inventory"), do: {:ok, "vial_inventory", &VialPlan.install!/2}
  defp demo_plan("vial"), do: demo_plan("vial_inventory")
  defp demo_plan(_kind), do: {:error, :unknown_demo_plan}

  defp install_demo_plan_with(actor, installer) do
    result = installer.(actor, starts_on: Date.utc_today())
    {:ok, Map.fetch!(result, :plan)}
  rescue
    _error -> {:error, :install_failed}
  end

  defp upcoming_work(plan, actor, date) do
    date
    |> next_days(3)
    |> Enum.reduce_while({:ok, []}, fn upcoming_date, {:ok, acc} ->
      case Plans.project_today(plan, actor: actor, date: upcoming_date, as_of_date: date) do
        {:ok, projection} -> {:cont, {:ok, acc ++ projection.projected_work}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

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
      diagnostics: projection.diagnostics,
      explanations: projection.explanations
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
      eventTypeId: event_type_id,
      eventTypeName: event_type && event_type.name,
      directGoalId: Map.get(payload, :direct_goal_id),
      directGoalKey: Map.get(payload, :direct_goal_key),
      session:
        session_work_json(
          work,
          slot_results_by_occurrence,
          session_slots_by_id,
          items_by_id
        ),
      canLog:
        work.kind == :direct_goal and work.status != :completed and not is_nil(event_type_id)
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
            reason: Map.get(item, :reason)
          }
        end),
      state: Map.get(occurrence, :session_state, %{}),
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
      eventInstanceId: slot_result.event_instance_id,
      notes: slot_result.notes
    }
  end

  defp target_json(target) when is_map(target) do
    %{
      quantity: map_value(target, "quantity"),
      unit: map_value(target, "unit"),
      quantityPath: map_value(target, "quantity_path"),
      summaryTemplate: map_value(target, "summary_template")
    }
  end

  defp target_json(_target), do: %{}

  defp plan_json(plan, summary \\ nil) do
    duration = Date.diff(plan.ends_on, plan.starts_on) + 1
    elapsed = Date.diff(Date.utc_today(), plan.starts_on) + 1

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
      summary: summary
    }
  end

  defp day_label(elapsed, duration) when elapsed >= 1 and elapsed <= duration do
    "Day #{elapsed} of #{duration}"
  end

  defp day_label(_elapsed, duration), do: "#{duration} day plan"

  defp item_json(item, item_types_by_id) do
    item_type = Map.get(item_types_by_id, item.item_type_id)

    %{
      id: item.id,
      key: item.key,
      name: item.name,
      typeId: item.item_type_id,
      typeKey: item_type && item_type.key,
      stateful: item.stateful,
      facts: item.facts,
      archived: not is_nil(item.archived_at)
    }
  end

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
      directGoalId: event.direct_goal_id,
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
      status: Atom.to_string(effect.status)
    }
  end

  defp log_attrs(params) do
    now = DateTime.utc_now()
    quantity = blank_to_nil(Map.get(params, "quantity"))
    unit = blank_to_nil(Map.get(params, "unit"))
    note = blank_to_nil(Map.get(params, "note"))
    payload = payload_with_quantity(Map.get(params, "payload", %{}), quantity, unit, note)

    attrs = %{
      plan_id: Map.get(params, "plan_id"),
      event_type_id: Map.get(params, "event_type_id"),
      direct_goal_id: blank_to_nil(Map.get(params, "direct_goal_id")),
      effective_at: parse_datetime(Map.get(params, "effective_at")) || now,
      recorded_at: now,
      summary: blank_to_nil(Map.get(params, "summary")) || "Logged event",
      quantity: quantity,
      unit: unit,
      note: note,
      payload: payload,
      item_links: item_links(Map.get(params, "item_links", []))
    }

    {:ok, attrs}
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

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_keyword(keyword, _key, nil), do: keyword
  defp maybe_put_keyword(keyword, _key, ""), do: keyword
  defp maybe_put_keyword(keyword, key, value), do: Keyword.put(keyword, key, value)

  defp decimal_string(nil), do: nil
  defp decimal_string(%Decimal{} = value), do: Decimal.to_string(value)
  defp decimal_string(value), do: to_string(value)

  defp app_error(conn, status, message) do
    conn
    |> put_status(status)
    |> json(%{error: %{message: message}})
  end
end
