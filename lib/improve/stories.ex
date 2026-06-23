defmodule Improve.Stories do
  @moduledoc """
  Thin helpers for executable product story scripts.

  Story helpers own scenario concerns: reset, demo users, stable story keys, and
  readable output. Product operations delegate to `Improve.App`.
  """

  import Ecto.Query, only: [from: 2]

  alias Improve.Accounts
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

  def user!(%Story{} = story, name, opts \\ []) do
    email = Keyword.get(opts, :email, default_email(story.key))

    user =
      case Accounts.get_user_by_email(email) do
        {:ok, user} -> user
        {:error, _error} -> Accounts.create_user!(%{email: email, full_name: name})
      end

    %{story | user: user}
  end

  def create_plan!(%Story{} = story, name, opts) do
    App.create_plan!(
      name,
      opts
      |> Keyword.put(:actor, actor!(story))
      |> Keyword.put_new(:source_kind, :demo)
      |> Keyword.put(:source_key, story.source_key)
    )
  end

  def add_event_type!(%Story{} = story, plan, name, opts) do
    App.add_event_type!(plan, name, Keyword.put(opts, :actor, actor!(story)))
  end

  def add_item_type!(%Story{} = story, plan, name, opts) do
    App.add_item_type!(plan, name, Keyword.put(opts, :actor, actor!(story)))
  end

  def add_item!(%Story{} = story, plan, name, opts) do
    App.add_item!(plan, name, Keyword.put(opts, :actor, actor!(story)))
  end

  def add_exercise!(%Story{} = story, plan, name, opts) do
    actor = actor!(story)

    if not Enum.any?(
         Plans.list_item_types!(actor: actor, query: [filter: [plan_id: plan.id]]),
         &(&1.key == "exercise")
       ) do
      App.add_item_type!(plan, "Exercise", actor: actor, key: "exercise")
    end

    App.add_item!(
      plan,
      name,
      opts
      |> Keyword.put(:actor, actor)
      |> Keyword.put(:type, "exercise")
      |> Keyword.put_new(:facts, %{})
    )
  end

  def add_pool!(%Story{} = story, plan, name, opts) do
    App.add_pool!(plan, name, Keyword.put(opts, :actor, actor!(story)))
  end

  def add_direct_goal!(%Story{} = story, plan, name, opts) do
    App.add_direct_goal!(plan, name, Keyword.put(opts, :actor, actor!(story)))
  end

  def add_session!(%Story{} = story, plan, name, opts) do
    App.add_session!(plan, name, Keyword.put(opts, :actor, actor!(story)))
  end

  def every_day, do: App.every_day()
  def every_week(opts), do: App.every_week(opts)
  def choose(count, opts), do: App.choose(count, opts)
  def subtract_quantity(opts), do: App.subtract_quantity(opts)

  def project_today!(%Story{} = story, plan, opts) do
    projection_opts =
      [actor: actor!(story), date: Keyword.fetch!(opts, :on)]
      |> maybe_put(:as_of_date, Keyword.get(opts, :as_of))

    App.project_today!(plan, projection_opts)
  end

  def start_session!(%Story{} = story, projection, session_key, opts \\ []) do
    App.start_session!(projection, session_key, Keyword.put(opts, :actor, actor!(story)))
  end

  def log_slot!(%Story{} = story, started_session, opts) do
    App.log_session_slot!(started_session, Keyword.put(opts, :actor, actor!(story)))
  end

  def log_direct_goal!(%Story{} = story, projection, opts) do
    App.log_direct_goal!(projection, Keyword.put(opts, :actor, actor!(story)))
  end

  def log_event!(%Story{} = story, plan, opts) do
    App.log_event!(plan, Keyword.put(opts, :actor, actor!(story)))
  end

  def correct_event!(%Story{} = story, original_log_or_event, opts) do
    App.correct_event!(original_log_or_event, Keyword.put(opts, :actor, actor!(story)))
  end

  def offline_event(%Story{} = story, plan, opts) do
    App.build_offline_event(plan, Keyword.put(opts, :actor, actor!(story)))
  end

  def submit_offline_events!(%Story{} = story, entries) do
    App.submit_offline_events!(entries, actor: actor!(story))
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
    summary = App.get_ai_plan_summary!(plan, actor: actor!(story))

    Print.section("AI Plan Summary")
    Print.inspect_value("summary", summary)

    summary
  end

  def show_ai_today_context!(%Story{} = story, plan, opts) do
    projection =
      App.get_ai_today_context!(plan,
        date: Keyword.fetch!(opts, :on),
        actor: actor!(story)
      )

    Print.section("AI Today Context")
    Print.inspect_value("projection", projection)

    projection
  end

  def show_ai_recent_journal!(%Story{} = story, plan, opts \\ []) do
    journal =
      App.get_ai_recent_journal!(plan,
        limit: Keyword.get(opts, :limit, 10),
        actor: actor!(story)
      )

    Print.section("AI Recent Journal")
    Print.inspect_value("journal", journal)

    journal
  end

  def show_ai_item_state!(%Story{} = story, plan, item_key) do
    state = App.get_ai_item_state!(plan, item_key, actor: actor!(story))

    Print.section("AI Item State")
    Print.inspect_value("state", state)

    state
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

  defp configure_story_logging!(opts) do
    quiet_logs? =
      Mix.env() == :dev and
        Keyword.get(opts, :quiet_logs?, true) and
        "--debug" not in System.argv()

    if quiet_logs? do
      Logger.configure(level: :info)
    end
  end

  defp session_slot_results!(story, occurrence) do
    Improve.Sessions.list_slot_results!(
      actor: actor!(story),
      query: [filter: [session_occurrence_id: occurrence.id]]
    )
  end

  defp item_index!(story, plan_id) do
    Plans.list_items!(actor: actor!(story), query: [filter: [plan_id: plan_id]])
    |> Map.new(&{&1.id, &1})
  end

  defp session_slot_index!(story, plan_id) do
    Plans.list_session_slots!(actor: actor!(story), query: [filter: [plan_id: plan_id]])
    |> Map.new(&{&1.id, &1})
  end

  defp item_name(nil), do: "(none)"
  defp item_name(item), do: item.name

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

  defp maybe_put(list, _key, nil), do: list
  defp maybe_put(list, key, value), do: Keyword.put(list, key, value)
end
