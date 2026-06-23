defmodule Improve.Stories do
  @moduledoc """
  Thin helpers for executable product story scripts.

  Story helpers are allowed to make scripts read like product workflows, but
  they should not contain product rules. Scheduling, projection, logging,
  effects, item state, and AI context all come from the existing domains.
  """

  import Ecto.Query, only: [from: 2]

  alias Improve.Accounts
  alias Improve.Ai
  alias Improve.App
  alias Improve.Journal
  alias Improve.Plans
  alias Improve.Repo
  alias Improve.Stories.Print
  alias Improve.Stories.Story

  def begin!(key, opts \\ []) when is_binary(key) do
    configure_story_logging!(opts)

    source_key = "story:#{key}"
    reset? = Keyword.get(opts, :reset?, true) and "--keep" not in System.argv()

    if "--rollback" in System.argv() do
      IO.puts("--rollback is not implemented yet; running as a normal story.")
    end

    if reset? do
      reset!(source_key)
    end

    %Story{key: key, source_key: source_key, reset?: reset?}
  end

  defp configure_story_logging!(opts) do
    quiet_logs? =
      Mix.env() == :dev and
        Keyword.get(opts, :quiet_logs?, true) and
        "--debug" not in System.argv()

    if quiet_logs? do
      Logger.configure(level: :info)
    end
  end

  def user!(%Story{} = story, name, opts \\ []) do
    email = Keyword.get(opts, :email, default_email(story.key))

    user =
      case Accounts.get_user_by_email(email) do
        {:ok, user} ->
          user

        {:error, _error} ->
          Accounts.create_user!(%{email: email, full_name: name})
      end

    %{story | user: user}
  end

  def create_plan!(%Story{} = story, name, opts) do
    Plans.create_plan!(
      %{
        name: name,
        intention: Keyword.fetch!(opts, :intention),
        starts_on: Keyword.fetch!(opts, :from),
        ends_on: Keyword.fetch!(opts, :until),
        status: Keyword.get(opts, :status, :active),
        source_kind: :demo,
        source_key: story.source_key
      },
      actor: actor!(story)
    )
  end

  def add_event_type!(%Story{} = story, plan, name, opts) do
    Plans.create_event_type!(
      %{
        plan_id: plan.id,
        key: Keyword.get(opts, :key, key_from(name)),
        name: name,
        description: Keyword.get(opts, :description),
        payload_schema: stringify_keys(Keyword.get(opts, :payload, %{})),
        item_link_roles: item_link_roles(Keyword.get(opts, :required_links, [])),
        effect_rules: effect_rules(Keyword.get(opts, :effects, []))
      },
      actor: actor!(story)
    )
  end

  def add_item_type!(%Story{} = story, plan, name, opts) do
    Plans.create_item_type!(
      %{
        plan_id: plan.id,
        key: Keyword.get(opts, :key, key_from(name)),
        name: name,
        description: Keyword.get(opts, :description),
        facts_schema: stringify_keys(Keyword.get(opts, :facts_schema, %{})),
        display_hints: stringify_keys(Keyword.get(opts, :display_hints, %{}))
      },
      actor: actor!(story)
    )
  end

  def add_item!(%Story{} = story, plan, name, opts) do
    item_type = item_type!(story, plan, Keyword.fetch!(opts, :type))

    Plans.create_item!(
      %{
        plan_id: plan.id,
        item_type_id: item_type.id,
        key: Keyword.get(opts, :key, key_from(name)),
        name: name,
        stateful: Keyword.get(opts, :stateful, false),
        facts: stringify_keys(Keyword.get(opts, :facts, %{}))
      },
      actor: actor!(story)
    )
  end

  def add_exercise!(%Story{} = story, plan, name, opts) do
    ensure_item_type!(story, plan, "exercise", "Exercise")

    add_item!(story, plan, name,
      key: Keyword.get(opts, :key, key_from(name)),
      type: "exercise",
      facts: Keyword.get(opts, :facts, %{})
    )
  end

  def add_pool!(%Story{} = story, plan, name, opts) do
    pool =
      Plans.create_pool!(
        %{
          plan_id: plan.id,
          key: Keyword.get(opts, :key, key_from(name)),
          name: name,
          description: Keyword.get(opts, :description)
        },
        actor: actor!(story)
      )

    opts
    |> Keyword.get(:items, [])
    |> Enum.each(fn item_key ->
      item = item!(story, plan, item_key)

      Plans.create_pool_membership!(
        %{plan_id: plan.id, pool_id: pool.id, item_id: item.id},
        actor: actor!(story)
      )
    end)

    pool
  end

  def add_direct_goal!(%Story{} = story, plan, name, opts) do
    event_type = event_type!(story, plan, Keyword.fetch!(opts, :event))
    schedule = Keyword.fetch!(opts, :schedule)

    direct_goal =
      Plans.create_direct_goal!(
        %{
          plan_id: plan.id,
          event_type_id: event_type.id,
          key: Keyword.get(opts, :key, key_from(name)),
          name: name,
          description: Keyword.get(opts, :description),
          target: stringify_keys(Keyword.get(opts, :target, %{})),
          completion_policy: stringify_keys(Keyword.get(opts, :completion_policy, %{})),
          missed_policy: stringify_keys(Keyword.get(opts, :missed_policy, %{}))
        },
        actor: actor!(story)
      )

    create_schedule!(story, plan, :direct_goal, direct_goal, schedule)
    direct_goal
  end

  def add_session!(%Story{} = story, plan, name, opts) do
    schedule = Keyword.fetch!(opts, :schedule)

    session_template =
      Plans.create_session_template!(
        %{
          plan_id: plan.id,
          key: Keyword.get(opts, :key, key_from(name)),
          name: name,
          description: Keyword.get(opts, :description),
          completion_policy: stringify_keys(Keyword.get(opts, :completion_policy, %{})),
          missed_policy: stringify_keys(Keyword.get(opts, :missed_policy, %{}))
        },
        actor: actor!(story)
      )

    opts
    |> Keyword.fetch!(:slots)
    |> Enum.with_index(1)
    |> Enum.each(fn {slot, position} ->
      pool = pool!(story, plan, Map.fetch!(slot, :from))

      Plans.create_session_slot!(
        %{
          plan_id: plan.id,
          session_template_id: session_template.id,
          key: Map.get(slot, :key, Map.fetch!(slot, :from)),
          name: Map.get(slot, :name, "#{pool.name} slot"),
          pool_id: pool.id,
          count: Map.fetch!(slot, :count),
          optional: Map.get(slot, :optional, false),
          rules: stringify_keys(Map.get(slot, :rules, %{})),
          position: position
        },
        actor: actor!(story)
      )
    end)

    create_schedule!(story, plan, :session_template, session_template, schedule)
    session_template
  end

  def every_day, do: %{kind: :every_day, rules: %{}}

  def choose(count, opts) do
    %{
      count: count,
      from: Keyword.fetch!(opts, :from),
      key: Keyword.get(opts, :key),
      name: Keyword.get(opts, :name),
      optional: Keyword.get(opts, :optional, false),
      rules: Keyword.get(opts, :rules, %{})
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  def every_week(opts) do
    %{
      kind: :times_per_week,
      rules: %{
        "times" => Keyword.fetch!(opts, :times),
        "allowed_weekdays" => opts |> Keyword.fetch!(:on) |> Enum.map(&weekday/1)
      }
    }
  end

  def project_today!(%Story{} = story, plan, opts) do
    projection_opts =
      [actor: actor!(story), date: Keyword.fetch!(opts, :on)]
      |> maybe_put(:as_of_date, Keyword.get(opts, :as_of))

    Plans.project_today!(plan, projection_opts)
  end

  def log_direct_goal!(%Story{} = story, projection, opts) do
    App.log_direct_goal!(projection, Keyword.put(opts, :actor, actor!(story)))
  end

  def start_session!(%Story{} = story, projection, session_key, opts \\ []) do
    App.start_session!(projection, session_key, Keyword.put(opts, :actor, actor!(story)))
  end

  def log_slot!(%Story{} = story, started_session, opts) do
    App.log_session_slot!(started_session, Keyword.put(opts, :actor, actor!(story)))
  end

  def log_event!(%Story{} = story, plan, opts) do
    App.log_event!(plan, Keyword.put(opts, :actor, actor!(story)))
  end

  def correct_event!(%Story{} = story, original_log_or_event, opts) do
    App.correct_event!(original_log_or_event, Keyword.put(opts, :actor, actor!(story)))
  end

  def offline_event(%Story{} = story, plan, opts) do
    App.offline_event(plan, Keyword.put(opts, :actor, actor!(story)))
  end

  def submit_offline_events!(%Story{} = story, entries) do
    App.submit_offline_events!(entries, actor: actor!(story))
  end

  def subtract_quantity(opts) do
    %{
      role: Keyword.fetch!(opts, :from),
      effect_type: "subtract_quantity",
      quantity_path: Keyword.fetch!(opts, :quantity),
      unit_path: Keyword.fetch!(opts, :unit)
    }
  end

  def show_plan_summary!(%Story{} = story, plan) do
    summary = Plans.summarize_plan!(plan, actor: actor!(story))

    Print.section("Plan Summary")

    Print.key_values([
      {"Plan", plan.name},
      {"Items", summary.items},
      {"Event types", summary.event_types},
      {"Direct goals", summary.direct_goals},
      {"Session templates", summary.session_templates},
      {"Schedules", summary.schedules}
    ])

    summary
  end

  def show_projection!(%Story{} = _story, projection) do
    Print.section("Projected Work")
    Print.key_values([{"Date", projection.date}])

    Print.rows(projection.projected_work, fn work ->
      "#{work.kind} #{work.status}: #{work.title}"
    end)

    projection
  end

  def show_session!(%Story{} = story, started_session) do
    show_session(story, started_session, "Session")
  end

  def show_session_results!(%Story{} = story, started_session) do
    show_session(story, started_session, "Session Results")
  end

  defp show_session(%Story{} = story, started_session, title) do
    occurrence = Map.fetch!(started_session, :session_occurrence)
    slot_results = session_slot_results!(story, occurrence)
    items = item_index!(story, occurrence.plan_id)
    slots = session_slot_index!(story, occurrence.plan_id)

    Print.section(title)

    Print.key_values([
      {"Planned for", occurrence.planned_for},
      {"Status", occurrence.status},
      {"Started at", occurrence.started_at}
    ])

    sorted_slot_results =
      Enum.sort_by(slot_results, fn slot_result ->
        slot = Map.fetch!(slots, slot_result.session_slot_id)
        {slot.position, slot.key, item_name(Map.get(items, slot_result.recommended_item_id))}
      end)

    Print.rows(sorted_slot_results, fn slot_result ->
      slot = Map.fetch!(slots, slot_result.session_slot_id)
      recommended = Map.get(items, slot_result.recommended_item_id)
      actual = Map.get(items, slot_result.actual_item_id)

      "#{slot.key} #{slot_result.status}: #{item_name(recommended)} -> #{item_name(actual)}"
    end)

    started_session
  end

  def show_journal!(%Story{} = story, plan) do
    events = Journal.read_journal!(plan, actor: actor!(story))

    Print.section("Journal")

    Print.rows(events, fn event ->
      "#{event.status} #{DateTime.to_iso8601(event.effective_at)} #{event.summary}"
    end)

    events
  end

  def show_offline_results!(%Story{} = _story, result) do
    Print.section("Offline Results")

    Print.rows(result.results, fn result ->
      details =
        [
          result.client_operation_id,
          result.conflict_category,
          result.event_instance_id
        ]
        |> Enum.reject(&is_nil/1)
        |> Enum.join(" ")

      "#{result.status}: #{details}"
    end)

    result
  end

  def show_item_state!(%Story{} = story, plan, item_key) do
    state = App.get_item_state!(plan, item_key, actor: actor!(story))

    Print.section("Item State")

    Print.key_values([
      {"Item", item_key},
      {"Current quantity", state.calculated_state.current_quantity},
      {"Unit", state.calculated_state.unit},
      {"Active effects", length(state.active_effects)},
      {"Warnings", length(state.warnings)}
    ])

    state
  end

  def show_ai_plan_summary!(%Story{} = story, plan) do
    summary = Ai.get_plan_summary!(plan.id, actor: actor!(story))

    Print.section("AI Plan Summary")
    Print.inspect_value("summary", summary)

    summary
  end

  def show_ai_today_context!(%Story{} = story, plan, opts) do
    projection = Ai.project_today!(plan.id, Keyword.fetch!(opts, :on), actor: actor!(story))

    Print.section("AI Today Context")
    Print.inspect_value("projection", projection)

    projection
  end

  def show_ai_recent_journal!(%Story{} = story, plan, opts \\ []) do
    journal =
      Ai.get_recent_journal_events!(plan.id, Keyword.get(opts, :limit, 10), actor: actor!(story))

    Print.section("AI Recent Journal")
    Print.inspect_value("journal", journal)

    journal
  end

  def show_ai_item_state!(%Story{} = story, plan, item_key) do
    item = item!(story, plan, item_key)
    state = Ai.get_item_state!(item.id, actor: actor!(story))

    Print.section("AI Item State")
    Print.inspect_value("state", state)

    state
  end

  defp create_schedule!(story, plan, owner_type, owner, schedule) do
    Plans.create_schedule!(
      %{
        plan_id: plan.id,
        owner_type: owner_type,
        owner_id: owner.id,
        kind: Map.fetch!(schedule, :kind),
        rules: Map.get(schedule, :rules, %{}),
        starts_on: plan.starts_on,
        ends_on: plan.ends_on
      },
      actor: actor!(story)
    )
  end

  defp event_type!(story, plan_or_id, key) do
    story
    |> event_types(plan_id(plan_or_id))
    |> Enum.find(&(&1.key == key))
    |> case do
      nil -> raise ArgumentError, "No event type #{inspect(key)} exists in this plan."
      event_type -> event_type
    end
  end

  defp event_types(story, plan_id) do
    Plans.list_event_types!(actor: actor!(story), query: [filter: [plan_id: plan_id]])
  end

  defp ensure_item_type!(story, plan, key, name) do
    case Enum.find(item_types(story, plan.id), &(&1.key == key)) do
      nil -> add_item_type!(story, plan, name, key: key)
      item_type -> item_type
    end
  end

  defp item_type!(story, plan_or_id, key) do
    story
    |> item_types(plan_id(plan_or_id))
    |> Enum.find(&(&1.key == key))
    |> case do
      nil -> raise ArgumentError, "No item type #{inspect(key)} exists in this plan."
      item_type -> item_type
    end
  end

  defp item_types(story, plan_id) do
    Plans.list_item_types!(actor: actor!(story), query: [filter: [plan_id: plan_id]])
  end

  defp item!(story, plan_or_id, key) do
    story
    |> items(plan_id(plan_or_id))
    |> Enum.find(&(&1.key == key))
    |> case do
      nil -> raise ArgumentError, "No item #{inspect(key)} exists in this plan."
      item -> item
    end
  end

  defp items(story, plan_id) do
    Plans.list_items!(actor: actor!(story), query: [filter: [plan_id: plan_id]])
  end

  defp pool!(story, plan_or_id, key) do
    story
    |> pools(plan_id(plan_or_id))
    |> Enum.find(&(&1.key == key))
    |> case do
      nil -> raise ArgumentError, "No pool #{inspect(key)} exists in this plan."
      pool -> pool
    end
  end

  defp pools(story, plan_id) do
    Plans.list_pools!(actor: actor!(story), query: [filter: [plan_id: plan_id]])
  end

  defp session_slot_results!(story, occurrence) do
    Improve.Sessions.list_slot_results!(
      actor: actor!(story),
      query: [filter: [session_occurrence_id: occurrence.id]]
    )
  end

  defp item_index!(story, plan_id) do
    story
    |> items(plan_id)
    |> Map.new(&{&1.id, &1})
  end

  defp session_slot_index!(story, plan_id) do
    Plans.list_session_slots!(actor: actor!(story), query: [filter: [plan_id: plan_id]])
    |> Map.new(&{&1.id, &1})
  end

  defp item_name(nil), do: "(none)"
  defp item_name(item), do: item.name

  defp item_link_roles([]), do: %{}

  defp item_link_roles(roles) do
    %{
      "roles" =>
        Enum.map(roles, fn role ->
          %{"role" => to_string(role), "required" => true}
        end)
    }
  end

  defp effect_rules([]), do: %{}
  defp effect_rules(rules), do: %{"rules" => Enum.map(rules, &stringify_keys/1)}

  defp reset!(source_key) do
    plan_ids =
      Repo.all(from plan in "plans", where: plan.source_key == ^source_key, select: plan.id)

    if plan_ids != [] do
      Repo.transaction(fn ->
        Repo.update_all(from(slot in "slot_results", where: slot.plan_id in ^plan_ids),
          set: [event_instance_id: nil]
        )

        delete_story_rows("item_effects", plan_ids)
        delete_story_rows("event_item_links", plan_ids)
        delete_story_rows("event_instances", plan_ids)
        delete_story_rows("slot_results", plan_ids)
        delete_story_rows("session_occurrences", plan_ids)
        delete_story_rows("schedules", plan_ids)
        delete_story_rows("pool_memberships", plan_ids)
        delete_story_rows("session_slots", plan_ids)
        delete_story_rows("session_templates", plan_ids)
        delete_story_rows("direct_goals", plan_ids)
        delete_story_rows("environments", plan_ids)
        delete_story_rows("pools", plan_ids)
        delete_story_rows("items", plan_ids)
        delete_story_rows("item_types", plan_ids)
        delete_story_rows("event_types", plan_ids)
        delete_story_rows("plans", plan_ids)
      end)
    end
  end

  defp delete_story_rows("plans", plan_ids) do
    Repo.delete_all(from(row in "plans", where: row.id in ^plan_ids))
  end

  defp delete_story_rows(table, plan_ids) do
    Repo.delete_all(from(row in table, where: row.plan_id in ^plan_ids))
  end

  defp default_email(key), do: "story+#{String.replace(key, "_", "-")}@example.test"

  defp actor!(%Story{user: nil}), do: raise("Story has no user. Call Story.user!/3 first.")
  defp actor!(%Story{user: user}), do: user

  defp plan_id(%{id: id}), do: id
  defp plan_id(id), do: id

  defp key_from(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "_")
    |> String.trim("_")
  end

  defp weekday(day) when is_atom(day), do: day |> Atom.to_string() |> weekday()
  defp weekday(day) when is_binary(day), do: day

  defp stringify_keys(value) when is_map(value) do
    Map.new(value, fn {key, value} -> {stringify_key(key), stringify_keys(value)} end)
  end

  defp stringify_keys(value) when is_list(value), do: Enum.map(value, &stringify_keys/1)
  defp stringify_keys(value), do: value

  defp stringify_key(key) when is_atom(key), do: Atom.to_string(key)
  defp stringify_key(key), do: key

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
