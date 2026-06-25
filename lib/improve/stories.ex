defmodule Improve.Stories do
  @moduledoc """
  Thin helpers for executable product story scripts.

  Story helpers own scenario concerns: reset, demo users, stable story keys, and
  readable output. Product operations delegate to `Improve.App`.
  """

  import Ecto.Query, only: [from: 2]

  alias Improve.Accounts
  alias Improve.App
  alias Improve.App.Value
  alias Improve.Journal
  alias Improve.Planning.Adaptation.MarathonPipeline
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

  def add_pool!(%Story{} = story, plan, name, opts) do
    App.add_pool!(plan, name, Keyword.put(opts, :actor, actor!(story)))
  end

  def add_track!(%Story{} = story, plan, name, opts) do
    App.add_track!(plan, name, Keyword.put(opts, :actor, actor!(story)))
  end

  def add_session!(%Story{} = story, plan, name, opts) do
    App.add_session!(plan, name, Keyword.put(opts, :actor, actor!(story)))
  end

  def add_time_off!(%Story{} = story, plan, opts) do
    App.add_time_off!(plan, Keyword.put(opts, :actor, actor!(story)))
  end

  def customize_plan!(%Story{} = story, plan, opts) do
    App.customize_plan!(plan, Keyword.put(opts, :actor, actor!(story)))
  end

  def every_day, do: App.every_day()
  def selected_weekdays(days), do: App.selected_weekdays(days)
  def every_n_days(days), do: App.every_n_days(days)
  def times_per_week(times), do: App.times_per_week(times)
  def times_per_week(times, opts), do: App.times_per_week(times, opts)
  def every_week(opts), do: App.every_week(opts)
  def every_n_weeks(weeks, opts), do: App.every_n_weeks(weeks, opts)
  def monthly(opts), do: App.monthly(opts)
  def after_completion(opts), do: App.after_completion(opts)
  def custom(description), do: App.custom(description)
  def choose(count, opts), do: App.choose(count, opts)
  def subtract_quantity(opts), do: App.subtract_quantity(opts)
  def add_quantity(opts), do: App.add_quantity(opts)
  def set_quantity(opts), do: App.set_quantity(opts)
  def fixed(quantity, unit), do: App.fixed(quantity, unit)
  def fixed(quantity, unit, opts), do: App.fixed(quantity, unit, opts)
  def metric(name), do: App.metric(name)
  def metric(name, opts), do: App.metric(name, opts)
  def checklist(items), do: App.checklist(items)
  def period_total(quantity, unit, opts), do: App.period_total(quantity, unit, opts)
  def progression(opts), do: App.progression(opts)
  def progression(from, to, opts), do: App.progression(from, to, opts)
  def adaptive(opts), do: App.adaptive(opts)
  def number(unit), do: App.number(unit)
  def number(unit, opts), do: App.number(unit, opts)
  def amount(unit), do: App.amount(unit)
  def amount(unit, opts), do: App.amount(unit, opts)
  def fields(fields), do: App.fields(fields)

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

  def skip_slot!(%Story{} = story, started_session, opts) do
    App.skip_session_slot!(started_session, Keyword.put(opts, :actor, actor!(story)))
  end

  def log_track!(%Story{} = story, projection, opts) do
    App.log_track!(projection, Keyword.put(opts, :actor, actor!(story)))
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
      {"Tracks", summary.tracks},
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
      operation = result.client_operation_id || "offline entry"

      case result.status do
        :accepted -> "accepted: #{operation}"
        :duplicate -> "duplicate: #{operation} matched an already accepted event"
        :needs_resolution -> "needs review: #{operation} #{result.conflict_category}"
        status -> "#{status}: #{operation}"
      end
    end)

    result
  end

  def show_correction_result!(%Story{} = _story, correction) do
    Print.section("Correction")

    Print.key_values([
      {"Original event", correction.corrected_event.status},
      {"Replacement event", correction.replacement.event.summary},
      {"Voided effects", length(correction.voided_effects)},
      {"Active replacement effects", length(correction.replacement.item_effects)}
    ])

    correction
  end

  def show_review!(%Story{} = story, plan, opts) do
    review = App.review!(plan, actor: actor!(story), on: Keyword.fetch!(opts, :on))

    Print.section("Review")

    Print.rows(review.observations, fn observation ->
      "#{observation.topic}: #{observation.text}"
    end)

    Print.section("Suggested Changes")

    Print.rows(review.suggested_changes, fn change ->
      "#{change.change}: #{change.text} #{change.reason}"
    end)

    review
  end

  def show_customization!(%Story{} = story, plan, result) do
    tracks = track_index!(story, plan.id)
    record = result.customization
    baseline = record.baseline

    Print.section("Baseline Customization")

    Print.key_values([
      {"Kind", record.kind},
      {"Baseline event", Value.value(baseline, "event_type_key")},
      {"Baseline payload", format_baseline(baseline)},
      {"Customization key", record.key}
    ])

    Print.rows(record.applied_changes, fn {track_key, applied} ->
      pace = Value.value(applied, "pace")
      track = Map.get(tracks, track_key)
      track_name = if track, do: track.name, else: track_key
      "#{track_name}: #{Value.value(pace, "label")}"
    end)

    record
  end

  def marathon_adaptation!(%Story{} = story, plan, projection, opts \\ []) do
    input = marathon_adaptation_input!(story, plan, projection, opts)

    case MarathonPipeline.evaluate(input) do
      {:ok, result} -> result
      {:error, error} -> raise inspect(error)
    end
  end

  def show_marathon_adaptation!(%Story{} = _story, result) do
    adaptation = result.outputs.marathon_adaptation
    recent_load = result.outputs.recent_load_km

    Print.section("Marathon Adaptation")

    Print.key_values([
      {"Evaluator order", Enum.map_join(result.order, " -> ", &to_string/1)},
      {"Recent load", "#{recent_load.value} #{recent_load.unit}"},
      {"Load window", "#{recent_load.window_start} to #{recent_load.as_of}"}
    ])

    Print.rows(adaptation.today, fn work ->
      action =
        case Map.get(work, :replacement) do
          nil -> to_string(work.action)
          replacement -> "#{work.action} #{replacement}"
        end

      "#{work.owner_key}: #{action} - #{work.reason}"
    end)

    Print.section("Derived Proposals")

    Print.rows(adaptation.proposals, fn proposal ->
      "#{proposal.kind}: #{proposal.text}"
    end)

    Print.section("Committed Proposals")

    Print.rows(adaptation.committed_proposals, fn proposal ->
      "#{proposal.kind}: #{proposal.text}"
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

  defp marathon_adaptation_input!(%Story{} = story, plan, projection, opts) do
    tracks = Plans.list_tracks!(actor: actor!(story), query: [filter: [plan_id: plan.id]])
    journal_events = Journal.read_journal!(plan, actor: actor!(story))

    time_off_windows =
      Plans.list_time_off_windows!(actor: actor!(story), query: [filter: [plan_id: plan.id]])

    %{
      date: projection.date,
      as_of_date: Keyword.get(opts, :as_of, projection.date),
      projected_work: projection.projected_work,
      recent_missed_work: Keyword.get(opts, :recent_missed_work, []),
      journal_events: journal_events,
      life_events: Keyword.get(opts, :life_events, []),
      time_off_windows: time_off_windows,
      plan_skeleton: %{
        id: plan.id,
        starts_on: plan.starts_on,
        ends_on: plan.ends_on,
        deadline: %{movable?: Keyword.get(opts, :deadline_movable?, false)}
      },
      track_guidance: Map.new(tracks, &{&1.key, &1.guidance}),
      tracks: tracks
    }
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

  defp track_index!(story, plan_id) do
    Plans.list_tracks!(actor: actor!(story), query: [filter: [plan_id: plan_id]])
    |> Map.new(&{&1.key, &1})
  end

  defp session_slot_index!(story, plan_id) do
    Plans.list_session_slots!(actor: actor!(story), query: [filter: [plan_id: plan_id]])
    |> Map.new(&{&1.id, &1})
  end

  defp item_name(nil), do: "(none)"
  defp item_name(item), do: item.name

  defp format_baseline(baseline) do
    payload = Value.value(baseline, "payload")
    minutes = Value.value(payload, "minutes")
    seconds = Value.value(payload, "seconds") || 0
    distance = Value.value(payload, "distance_km")
    "#{minutes}:#{String.pad_leading(Integer.to_string(seconds), 2, "0")} #{distance} km"
  end

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
        delete_story_rows("customizations", plan_ids)
        delete_story_rows("pool_memberships", plan_ids)
        delete_story_rows("session_slots", plan_ids)
        delete_story_rows("session_templates", plan_ids)
        delete_story_rows("tracks", plan_ids)
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
