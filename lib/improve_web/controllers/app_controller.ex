defmodule ImproveWeb.AppController do
  use ImproveWeb, :controller

  alias Improve.Journal
  alias Improve.Plans

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
         {:ok, upcoming} <- upcoming_work(plan, actor, date) do
      event_types_by_id = Map.new(event_types, &{&1.id, &1})
      item_types_by_id = Map.new(item_types, &{&1.id, &1})
      plan_by_id = Map.new(plans, &{&1.id, &1})

      {:ok,
       %{
         plans: Enum.map(plans, &plan_json/1),
         currentPlan: plan_json(plan, summary),
         today: today_json(projection, plan, event_types_by_id, upcoming),
         journal:
           journal_events
           |> Enum.take(-5)
           |> Enum.reverse()
           |> Enum.map(&event_json(&1, plan_by_id, event_types_by_id)),
         planDetail: %{
           summary: plan_json(plan, summary),
           items: Enum.map(items, &item_json(&1, item_types_by_id)),
           eventTypes: Enum.map(event_types, &event_type_json/1)
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

  defp today_json(projection, plan, event_types_by_id, upcoming) do
    work = Enum.map(projection.projected_work, &work_json(&1, plan, event_types_by_id))
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
        |> Enum.map(&work_json(&1, plan, event_types_by_id)),
      diagnostics: projection.diagnostics,
      explanations: projection.explanations
    }
  end

  defp work_json(work, plan, event_types_by_id) do
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
      session: session_work_json(work),
      canLog:
        work.kind == :direct_goal and work.status != :completed and not is_nil(event_type_id)
    }
  end

  defp session_work_json(%{kind: :session, payload: %{session_occurrence: occurrence}}) do
    %{
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
      state: Map.get(occurrence, :session_state, %{})
    }
  end

  defp session_work_json(_work), do: nil

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

  defp event_type_json(event_type) do
    %{
      id: event_type.id,
      key: event_type.key,
      name: event_type.name,
      description: event_type.description,
      payloadSchema: event_type.payload_schema,
      itemLinkRoles: event_type.item_link_roles
    }
  end

  defp event_json(event, plans_by_id, event_types_by_id) do
    plan = plans_by_id && Map.get(plans_by_id, event.plan_id)
    event_type = event_types_by_id && Map.get(event_types_by_id, event.event_type_id)

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
      recordedAt: DateTime.to_iso8601(event.recorded_at)
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

  defp decimal_string(nil), do: nil
  defp decimal_string(%Decimal{} = value), do: Decimal.to_string(value)
  defp decimal_string(value), do: to_string(value)

  defp app_error(conn, status, message) do
    conn
    |> put_status(status)
    |> json(%{error: %{message: message}})
  end
end
