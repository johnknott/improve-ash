defmodule Improve.Journal do
  use Ash.Domain,
    extensions: [AshTypescript.Rpc],
    otp_app: :improve

  require Ash.Query

  alias Improve.CommandError
  alias Improve.Journal.EventContract
  alias Improve.Journal.EventInstance
  alias Improve.Journal.LogEventCommand
  alias Improve.Journal.OfflineIngressResult
  alias Improve.Planning.EffectRuleInterpreter
  alias Improve.Plans
  alias Improve.Repo
  alias Improve.Sessions

  typescript_rpc do
    resource Improve.Journal.EventInstance do
      rpc_action(:list_events, :read)
      rpc_action(:get_event, :read, get_by: [:id])
    end

    resource Improve.Journal.ItemEffect do
      rpc_action(:list_item_effects, :read)
    end
  end

  resources do
    resource Improve.Journal.EventInstance do
      define :log_event, action: :log
      define :get_event, action: :read, get_by: [:id]
      define :list_events, action: :read
      define :void_event, action: :void
      define :mark_event_corrected, action: :mark_corrected
    end

    resource Improve.Journal.EventItemLink do
      define :create_event_item_link, action: :create
      define :list_event_item_links, action: :read
    end

    resource Improve.Journal.ItemEffect do
      define :create_item_effect, action: :create
      define :list_item_effects, action: :read
      define :void_item_effect, action: :void
    end
  end

  @notifications_key {__MODULE__, :notifications}
  @journal_page_default_limit 20
  @journal_page_max_limit 50
  @journal_statuses [:active, :corrected, :voided, :skipped]

  def log_generic_event(attrs, opts) do
    actor = Keyword.fetch!(opts, :actor)

    with {:ok, command} <- LogEventCommand.from_attrs(attrs),
         {:new, event_type} <- prepare_log_event_command(command, actor) do
      transact(fn ->
        reset_notifications!()

        {create_log_event_command!(command, actor, event_type, []), take_notifications!()}
      end)
      |> case do
        {:ok, {result, notifications}} ->
          Ash.Notifier.notify(notifications)
          {:ok, result}

        {:error, error} ->
          case existing_idempotent_log(command, actor) do
            nil -> {:error, error}
            result -> {:ok, result}
          end
      end
    else
      {:duplicate, result} -> {:ok, result}
      {:error, diagnostics} -> {:error, diagnostics}
    end
  end

  def log_generic_event!(attrs, opts) do
    case log_generic_event(attrs, opts) do
      {:ok, result} -> result
      {:error, error} -> CommandError.raise!(:log_generic_event, error)
    end
  end

  def submit_offline_event_batch(entries, opts) when is_list(entries) do
    actor = Keyword.fetch!(opts, :actor)

    results =
      entries
      |> Enum.with_index(1)
      |> Enum.map(fn {attrs, index} -> submit_offline_event(attrs, index, actor) end)

    {:ok, %{results: results}}
  end

  def submit_offline_event_batch(_entries, _opts) do
    {:error, ["Offline event batch must be a list."]}
  end

  def submit_offline_event_batch!(entries, opts) do
    case submit_offline_event_batch(entries, opts) do
      {:ok, result} -> result
      {:error, diagnostics} -> CommandError.raise!(:submit_offline_event_batch, diagnostics)
    end
  end

  def log_session_item_event!(attrs, opts) do
    actor = Keyword.fetch!(opts, :actor)
    slot_result = Map.fetch!(attrs, :slot_result)
    item = Map.fetch!(attrs, :item)
    event_type = Map.fetch!(attrs, :event_type)
    session_occurrence = Map.fetch!(attrs, :session_occurrence)
    role = Map.fetch!(attrs, :role)

    CommandError.wrap!(:log_session_item_event, fn ->
      case log_generic_event(
             session_item_event_attrs(
               attrs,
               session_occurrence,
               slot_result,
               event_type,
               item,
               role
             ),
             actor: actor
           ) do
        {:ok, result} ->
          %{
            event: result.event,
            event_item_link: List.first(result.event_item_links),
            slot_result: result.slot_result
          }

        {:error, error} ->
          CommandError.raise!(:log_session_item_event, error)
      end
    end)
  end

  defp session_item_event_attrs(attrs, session_occurrence, slot_result, event_type, item, role) do
    %{
      plan_id: session_occurrence.plan_id,
      event_type_id: event_type.id,
      session_occurrence_id: session_occurrence.id,
      slot_result_id: slot_result.id,
      effective_at: Map.fetch!(attrs, :effective_at),
      recorded_at: Map.fetch!(attrs, :recorded_at),
      summary: Map.fetch!(attrs, :summary),
      quantity: Map.get(attrs, :quantity),
      unit: Map.get(attrs, :unit),
      payload: Map.get(attrs, :payload, %{}),
      note: Map.get(attrs, :note),
      origin: Map.get(attrs, :origin, :manual),
      idempotency: Map.get(attrs, :idempotency),
      item_links: [
        %{
          role: role,
          item_id: item.id,
          metadata: Map.get(attrs, :link_metadata, %{})
        }
      ]
    }
  end

  def log_linked_item_event!(attrs, opts) do
    actor = Keyword.fetch!(opts, :actor)
    plan = Map.fetch!(attrs, :plan)
    event_type = Map.fetch!(attrs, :event_type)
    linked_item = Map.fetch!(attrs, :linked_item)
    role = Map.fetch!(attrs, :role)

    ensure_actor_owns_plan!(:log_linked_item_event, plan, actor)

    result =
      log_generic_event!(
        linked_item_event_command_attrs(attrs, plan, event_type, linked_item, role),
        actor: actor
      )

    %{
      event: result.event,
      event_item_link: List.first(result.event_item_links),
      item_effects: result.item_effects
    }
  end

  def correct_linked_item_event!(attrs, opts) do
    actor = Keyword.fetch!(opts, :actor)
    plan = Map.fetch!(attrs, :plan)
    event_type = Map.fetch!(attrs, :event_type)
    linked_item = Map.fetch!(attrs, :linked_item)
    role = Map.fetch!(attrs, :role)
    original_event = Map.fetch!(attrs, :original_event)
    original_effect = Map.fetch!(attrs, :original_effect)

    ensure_actor_owns_plan!(:correct_linked_item_event, plan, actor)

    replacement_attrs =
      linked_item_event_command_attrs(attrs, plan, event_type, linked_item, role,
        default_summary: "Event corrected",
        link_metadata: %{"corrects_event_instance_id" => original_event.id}
      )

    correction =
      correct_generic_event!(
        %{
          original_event: original_event,
          original_effects: [original_effect],
          corrected_at: Map.fetch!(attrs, :corrected_at),
          correction_note: Map.get(attrs, :correction_note, "Corrected by replacement event"),
          replacement: replacement_attrs
        },
        actor: actor
      )

    %{
      corrected_event: correction.corrected_event,
      voided_effect: List.first(correction.voided_effects),
      replacement_event: correction.replacement.event,
      replacement_link: List.first(correction.replacement.event_item_links),
      replacement_effects: correction.replacement.item_effects
    }
  end

  defp ensure_actor_owns_plan!(_operation, %{user_id: user_id}, %{id: user_id}), do: :ok

  defp ensure_actor_owns_plan!(operation, _plan, _actor) do
    CommandError.forbidden!(operation, ["Plan is not available to this actor."])
  end

  def correct_generic_event(attrs, opts) do
    actor = Keyword.fetch!(opts, :actor)

    with {:ok, command} <- correction_command(attrs),
         :ok <- validate_log_event_command(command.replacement, actor) do
      transact(fn ->
        reset_notifications!()

        {persist_correction_command!(command, actor), take_notifications!()}
      end)
      |> case do
        {:ok, {result, notifications}} ->
          Ash.Notifier.notify(notifications)
          {:ok, result}

        {:error, error} ->
          {:error, error}
      end
    end
  end

  defp validate_log_event_command(command, actor) do
    case prepare_log_event_command(command, actor) do
      {:new, _event_type} -> :ok
      {:duplicate, _result} -> :ok
      {:error, diagnostics} -> {:error, diagnostics}
    end
  end

  def correct_generic_event!(attrs, opts) do
    case correct_generic_event(attrs, opts) do
      {:ok, result} -> result
      {:error, error} -> CommandError.raise!(:correct_generic_event, error)
    end
  end

  defp persist_correction_command!(command, actor) do
    %LogEventCommand{} = replacement = command.replacement

    replacement_command =
      %LogEventCommand{
        replacement
        | replaces_event_instance_id:
            replacement.replaces_event_instance_id || command.original_event.id,
          item_links:
            Enum.map(
              replacement.item_links,
              &annotate_replacement_link(&1, command.original_event)
            )
      }

    corrected_event =
      create!(
        __MODULE__,
        :mark_event_corrected!,
        actor,
        command.original_event,
        %{
          voided_at: command.corrected_at,
          note: command.correction_note
        }
      )

    voided_effects =
      Enum.map(command.original_effects, fn effect ->
        create!(
          __MODULE__,
          :void_item_effect!,
          actor,
          effect,
          %{voided_at: command.corrected_at}
        )
      end)

    replacement =
      persist_log_event_command!(replacement_command, actor,
        replaces_item_effects: command.original_effects
      )

    %{
      corrected_event: corrected_event,
      voided_effects: voided_effects,
      replacement: replacement
    }
  end

  defp annotate_replacement_link(item_link, original_event) do
    metadata =
      item_link.metadata
      |> Kernel.||(%{})
      |> Map.put("corrects_event_instance_id", original_event.id)

    %{item_link | metadata: metadata}
  end

  defp correction_command(attrs) do
    original_event = value(attrs, :original_event)
    original_effects = normalize_effects(value(attrs, :original_effects, []))
    corrected_at = value(attrs, :corrected_at)
    correction_note = value(attrs, :correction_note, "Corrected by replacement event")
    replacement_attrs = value(attrs, :replacement)

    replacement_result = LogEventCommand.from_attrs(replacement_attrs)

    diagnostics =
      []
      |> maybe_add(blank?(original_event), "Original event is required.")
      |> maybe_add(blank?(corrected_at), "Corrected time is required.")
      |> maybe_add(blank?(replacement_attrs), "Replacement event is required.")
      |> maybe_add(original_effects == :invalid, "Original effects must be a list.")
      |> then(&(&1 ++ original_effect_diagnostics(original_event, original_effects)))
      |> then(fn diagnostics ->
        case replacement_result do
          {:ok, _replacement} -> diagnostics
          {:error, replacement_diagnostics} -> diagnostics ++ replacement_diagnostics
        end
      end)

    case {diagnostics, replacement_result} do
      {[], {:ok, replacement}} ->
        {:ok,
         %{
           original_event: original_event,
           original_effects: original_effects,
           corrected_at: corrected_at,
           correction_note: correction_note,
           replacement: replacement
         }}

      {diagnostics, _replacement_result} ->
        {:error, diagnostics}
    end
  end

  defp normalize_effects(nil), do: []
  defp normalize_effects(effects) when is_list(effects), do: effects
  defp normalize_effects(_effects), do: :invalid

  defp original_effect_diagnostics(_original_event, :invalid), do: []
  defp original_effect_diagnostics(nil, _original_effects), do: []

  defp original_effect_diagnostics(original_event, original_effects) do
    original_effects
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {effect, index} ->
      if effect_belongs_to_event?(effect, original_event) do
        []
      else
        [
          "Original effect #{index} must belong to the original event."
        ]
      end
    end)
  end

  defp effect_belongs_to_event?(%{event_instance_id: event_instance_id}, %{id: event_id}) do
    event_instance_id == event_id
  end

  defp effect_belongs_to_event?(_effect, _original_event), do: false

  defp value(map, key, default \\ nil)

  defp value(map, key, default) when is_map(map) do
    Map.get(map, key, Map.get(map, Atom.to_string(key), default))
  end

  defp value(_other, _key, default), do: default

  defp maybe_add(diagnostics, true, message), do: diagnostics ++ [message]
  defp maybe_add(diagnostics, false, _message), do: diagnostics

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?([]), do: true
  defp blank?(_value), do: false

  defp submit_offline_event(attrs, index, actor) do
    attrs = offline_attrs(attrs)

    with {:ok, command} <- LogEventCommand.from_attrs(attrs),
         :ok <- validate_offline_references(command, actor),
         {:ok, log_result} <- log_generic_event(attrs, actor: actor) do
      OfflineIngressResult.accepted(index, attrs, log_result)
    else
      {:error, diagnostics} when is_list(diagnostics) ->
        OfflineIngressResult.rejected(index, attrs, diagnostics)

      {:needs_resolution, diagnostics, conflict_category} ->
        OfflineIngressResult.needs_resolution(index, attrs, diagnostics, conflict_category)

      {:error, error} ->
        offline_failure_result(index, attrs, error)
    end
  rescue
    error ->
      offline_failure_result(index, attrs, error)
  end

  defp offline_attrs(attrs) when is_map(attrs) do
    Map.put_new(attrs, :origin, :offline_sync)
  end

  defp offline_attrs(attrs), do: attrs

  defp offline_failure_result(index, attrs, error) do
    diagnostics = error_diagnostics(error)

    case conflict_category(diagnostics) do
      :invalid_payload ->
        OfflineIngressResult.rejected(index, attrs, diagnostics)

      category ->
        OfflineIngressResult.needs_resolution(index, attrs, diagnostics, category)
    end
  end

  defp error_diagnostics(error) when is_exception(error), do: [Exception.message(error)]
  defp error_diagnostics(error) when is_binary(error), do: [error]
  defp error_diagnostics(error) when is_list(error), do: error
  defp error_diagnostics(error), do: [inspect(error)]

  defp conflict_category(diagnostics) do
    text = diagnostics |> Enum.map_join(" ", &to_string/1) |> String.downcase()

    cond do
      String.contains?(text, "must belong to the same plan") ->
        :cross_plan_reference

      String.contains?(text, "not found") ->
        :missing_plan_record

      true ->
        :invalid_payload
    end
  end

  defp validate_offline_references(command, actor) do
    [
      fn -> validate_plan_reference(command.plan_id, actor) end,
      fn -> validate_plan_record(:event_type, command.event_type_id, command.plan_id, actor) end,
      fn ->
        validate_plan_record(
          :session_occurrence,
          command.session_occurrence_id,
          command.plan_id,
          actor
        )
      end,
      fn ->
        validate_plan_record(:slot_result, command.slot_result_id, command.plan_id, actor)
      end,
      fn ->
        validate_plan_record(:track, command.track_id, command.plan_id, actor)
      end,
      fn -> validate_item_links(command.item_links, command.plan_id, actor) end,
      fn -> validate_slot_freshness(command, actor) end,
      fn -> validate_session_freshness(command, actor) end
    ]
    |> Enum.reduce_while(:ok, fn check, :ok ->
      case check.() do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_plan_reference(plan_id, actor) do
    case Plans.get_plan(plan_id, actor: actor) do
      {:ok, %{status: :archived}} ->
        needs_resolution(
          "Plan is archived and cannot accept offline logs.",
          :archived_plan_record
        )

      {:ok, _plan} ->
        :ok

      {:error, _error} ->
        needs_resolution("Plan is missing or no longer available.", :missing_plan_record)
    end
  end

  defp validate_plan_record(_kind, nil, _plan_id, _actor), do: :ok

  defp validate_plan_record(kind, id, plan_id, actor) do
    case fetch_plan_record(kind, id, actor) do
      {:ok, record} ->
        validate_record_plan(kind, record, plan_id)

      {:error, _error} ->
        needs_resolution(
          "#{record_label(kind)} is missing or no longer available.",
          :missing_plan_record
        )
    end
  end

  defp fetch_plan_record(:event_type, id, actor), do: Plans.get_event_type(id, actor: actor)

  defp fetch_plan_record(:session_occurrence, id, actor),
    do: Sessions.get_session_occurrence(id, actor: actor)

  defp fetch_plan_record(:slot_result, id, actor), do: Sessions.get_slot_result(id, actor: actor)
  defp fetch_plan_record(:track, id, actor), do: Plans.get_track(id, actor: actor)
  defp fetch_plan_record(:item, id, actor), do: Plans.get_item(id, actor: actor)

  defp validate_record_plan(:item, %{archived_at: archived_at}, _plan_id)
       when not is_nil(archived_at) do
    needs_resolution(
      "Item is archived and cannot be used by a new offline log.",
      :archived_plan_record
    )
  end

  defp validate_record_plan(kind, %{plan_id: plan_id}, plan_id), do: validate_record_state(kind)

  defp validate_record_plan(kind, _record, _plan_id) do
    needs_resolution("#{record_label(kind)} belongs to another plan.", :cross_plan_reference)
  end

  defp validate_record_state(_kind), do: :ok

  defp validate_item_links(item_links, plan_id, actor) do
    item_links
    |> Enum.reduce_while(:ok, fn item_link, :ok ->
      case validate_plan_record(:item, item_link.item_id, plan_id, actor) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_slot_freshness(%{slot_result_id: nil}, _actor), do: :ok

  defp validate_slot_freshness(command, actor) do
    case Sessions.get_slot_result(command.slot_result_id, actor: actor) do
      {:ok, %{event_instance_id: event_instance_id}}
      when not is_nil(event_instance_id) and
             event_instance_id != command.replaces_event_instance_id ->
        needs_resolution(
          "Slot result is already linked to another event.",
          :stale_session_state
        )

      {:ok, %{event_instance_id: event_instance_id}}
      when not is_nil(command.replaces_event_instance_id) and
             event_instance_id == command.replaces_event_instance_id ->
        :ok

      {:ok, %{status: status}} when status in [:completed, :skipped] ->
        needs_resolution("Slot result has already changed state.", :stale_session_state)

      {:ok, slot_result}
      when not is_nil(command.session_occurrence_id) and
             slot_result.session_occurrence_id != command.session_occurrence_id ->
        needs_resolution(
          "Slot result no longer belongs to the submitted session.",
          :stale_session_state
        )

      {:ok, _slot_result} ->
        :ok

      {:error, _error} ->
        needs_resolution("Slot result is missing or no longer available.", :missing_plan_record)
    end
  end

  defp validate_session_freshness(%{session_occurrence_id: nil}, _actor), do: :ok

  defp validate_session_freshness(%{replaces_event_instance_id: event_id}, _actor)
       when not is_nil(event_id),
       do: :ok

  defp validate_session_freshness(command, actor) do
    case Sessions.get_session_occurrence(command.session_occurrence_id, actor: actor) do
      {:ok, %{status: status}} when status in [:completed, :missed, :skipped] ->
        needs_resolution("Session occurrence has already changed state.", :stale_session_state)

      {:ok, _session_occurrence} ->
        :ok

      {:error, _error} ->
        needs_resolution(
          "Session occurrence is missing or no longer available.",
          :missing_plan_record
        )
    end
  end

  defp needs_resolution(diagnostic, conflict_category) do
    {:needs_resolution, [diagnostic], conflict_category}
  end

  defp record_label(:event_type), do: "Event type"
  defp record_label(:session_occurrence), do: "Session occurrence"
  defp record_label(:slot_result), do: "Slot result"
  defp record_label(:track), do: "Track"
  defp record_label(:item), do: "Item"

  defp transact(fun) when is_function(fun, 0) do
    Repo.transaction(fun)
  rescue
    error -> {:error, error}
  end

  def read_journal(plan_or_id, opts) do
    actor = Keyword.fetch!(opts, :actor)
    limit = Keyword.get(opts, :limit)

    with {:ok, plan} <- fetch_plan(plan_or_id, actor) do
      query_opts =
        [
          filter: [plan_id: plan.id],
          sort: journal_sort(limit)
        ]
        |> maybe_add_limit(limit)

      case list_events(actor: actor, query: query_opts) do
        {:ok, events} when is_integer(limit) -> {:ok, Enum.reverse(events)}
        result -> result
      end
    end
  end

  def journal_statuses, do: @journal_statuses

  def correction_context(event_or_id, opts) do
    actor = Keyword.fetch!(opts, :actor)

    with {:ok, event} <- get_event(id(event_or_id), actor: actor),
         {:ok, event} <-
           Ash.load(
             event,
             [
               :event_type,
               event_item_links: [:item],
               item_effects: [:item, :replaces_item_effect]
             ],
             actor: actor
           ) do
      event_item_links = Enum.sort_by(event.event_item_links, &{&1.inserted_at, &1.id})
      item_effects = Enum.sort_by(event.item_effects, &{&1.inserted_at, &1.id})
      eligibility = correction_eligibility(event, event_item_links, item_effects)

      if eligibility.eligible do
        {:ok,
         %{
           event: event,
           event_type: event.event_type,
           event_item_links: event_item_links,
           item_effects: item_effects
         }}
      else
        {:error, [eligibility.unavailable_reason]}
      end
    end
  end

  def read_journal_page(plan_or_id, opts) do
    actor = Keyword.fetch!(opts, :actor)

    with {:ok, plan} <- fetch_plan(plan_or_id, actor),
         {:ok, page_options} <- journal_page_options(opts),
         {:ok, cursor_event} <- journal_cursor_event(plan.id, page_options, actor),
         {:ok, events} <- journal_page_events(plan.id, page_options, cursor_event, actor),
         page_events = Enum.take(events, page_options.limit),
         {:ok, page_events} <- load_journal_page_events(page_events, actor),
         {:ok, replacements} <- replacement_events(plan.id, page_events, actor) do
      has_more? = length(events) > page_options.limit

      {:ok,
       %{
         plan: plan,
         events: page_events,
         replacements_by_event_id: Enum.group_by(replacements, & &1.replaces_event_instance_id),
         page_info: %{
           limit: page_options.limit,
           has_more?: has_more?,
           next_cursor: next_journal_cursor(page_events, has_more?)
         },
         applied_filters: Map.drop(page_options, [:cursor, :limit])
       }}
    end
  end

  def correction_eligibility(%{status: :active}, event_item_links, item_effects)
      when is_list(event_item_links) and is_list(item_effects) do
    case item_effects do
      [] ->
        %{eligible: true, unavailable_reason: nil}

      [%{status: :active, item_id: item_id}] ->
        if Enum.any?(event_item_links, &(&1.item_id == item_id)) do
          %{eligible: true, unavailable_reason: nil}
        else
          complex_correction_eligibility()
        end

      [%{status: _status}] ->
        %{
          eligible: false,
          unavailable_reason:
            "This entry has a state change that was already altered, so it cannot be corrected safely."
        }

      _multiple_effects ->
        complex_correction_eligibility()
    end
  end

  def correction_eligibility(%{status: :corrected}, _event_item_links, _item_effects) do
    %{eligible: false, unavailable_reason: "This entry has already been corrected."}
  end

  def correction_eligibility(%{status: :voided}, _event_item_links, _item_effects) do
    %{eligible: false, unavailable_reason: "Voided entries cannot be corrected."}
  end

  def correction_eligibility(%{status: :skipped}, _event_item_links, _item_effects) do
    %{
      eligible: false,
      unavailable_reason: "Skipped entries are superseded by logging what actually happened."
    }
  end

  def correction_eligibility(_event, _event_item_links, _item_effects) do
    %{eligible: false, unavailable_reason: "This entry cannot be corrected."}
  end

  defp complex_correction_eligibility do
    %{
      eligible: false,
      unavailable_reason: "This entry has state changes that need a richer correction flow."
    }
  end

  defp journal_page_options(opts) do
    with {:ok, limit} <- journal_page_limit(Keyword.get(opts, :limit)),
         {:ok, cursor} <- journal_page_uuid(Keyword.get(opts, :cursor), "Journal cursor"),
         {:ok, track_id} <- journal_page_uuid(Keyword.get(opts, :track_id), "Track filter"),
         {:ok, item_id} <- journal_page_uuid(Keyword.get(opts, :item_id), "Item filter"),
         {:ok, event_type_id} <-
           journal_page_uuid(Keyword.get(opts, :event_type_id), "Event type filter"),
         {:ok, status} <- journal_page_status(Keyword.get(opts, :status)) do
      {:ok,
       %{
         limit: limit,
         cursor: cursor,
         track_id: track_id,
         item_id: item_id,
         event_type_id: event_type_id,
         status: status
       }}
    end
  end

  defp journal_page_limit(nil), do: {:ok, @journal_page_default_limit}
  defp journal_page_limit(""), do: {:ok, @journal_page_default_limit}

  defp journal_page_limit(limit) when is_binary(limit) do
    case Integer.parse(String.trim(limit)) do
      {parsed, ""} -> journal_page_limit(parsed)
      _other -> invalid_journal_page_limit()
    end
  end

  defp journal_page_limit(limit)
       when is_integer(limit) and limit >= 1 and limit <= @journal_page_max_limit,
       do: {:ok, limit}

  defp journal_page_limit(_limit), do: invalid_journal_page_limit()

  defp invalid_journal_page_limit do
    {:error, ["Journal page size must be between 1 and #{@journal_page_max_limit}."]}
  end

  defp journal_page_uuid(nil, _label), do: {:ok, nil}
  defp journal_page_uuid("", _label), do: {:ok, nil}

  defp journal_page_uuid(value, label) when is_binary(value) do
    case Ash.Type.cast_input(Ash.Type.UUID, String.trim(value)) do
      {:ok, uuid} -> {:ok, uuid}
      {:error, _error} -> {:error, ["#{label} is invalid."]}
    end
  end

  defp journal_page_uuid(_value, label), do: {:error, ["#{label} is invalid."]}

  defp journal_page_status(nil), do: {:ok, nil}
  defp journal_page_status(""), do: {:ok, nil}

  defp journal_page_status(status) when is_binary(status) do
    status
    |> String.trim()
    |> String.downcase()
    |> case do
      "active" -> {:ok, :active}
      "corrected" -> {:ok, :corrected}
      "voided" -> {:ok, :voided}
      "skipped" -> {:ok, :skipped}
      _other -> invalid_journal_page_status()
    end
  end

  defp journal_page_status(status) when status in @journal_statuses, do: {:ok, status}
  defp journal_page_status(_status), do: invalid_journal_page_status()

  defp invalid_journal_page_status do
    {:error, ["Journal status must be active, corrected, voided, or skipped."]}
  end

  defp journal_cursor_event(_plan_id, %{cursor: nil}, _actor), do: {:ok, nil}

  defp journal_cursor_event(plan_id, page_options, actor) do
    query =
      plan_id
      |> journal_page_base_query(page_options)
      |> Ash.Query.filter(id == ^page_options.cursor)
      |> Ash.Query.limit(1)

    case list_events(actor: actor, query: query) do
      {:ok, [event]} -> {:ok, event}
      {:ok, []} -> {:error, ["Journal cursor is not valid for these filters."]}
      {:error, error} -> {:error, error}
    end
  end

  defp journal_page_events(plan_id, page_options, cursor_event, actor) do
    query =
      plan_id
      |> journal_page_base_query(page_options)
      |> maybe_filter_older_than(cursor_event)
      |> Ash.Query.sort(
        effective_at: :desc,
        recorded_at: :desc,
        inserted_at: :desc,
        id: :desc
      )
      |> Ash.Query.limit(page_options.limit + 1)

    list_events(actor: actor, query: query)
  end

  defp journal_page_base_query(plan_id, page_options) do
    EventInstance
    |> Ash.Query.filter(plan_id == ^plan_id)
    |> maybe_filter_journal_track(page_options.track_id)
    |> maybe_filter_journal_item(page_options.item_id)
    |> maybe_filter_journal_event_type(page_options.event_type_id)
    |> maybe_filter_journal_status(page_options.status)
  end

  defp maybe_filter_journal_track(query, nil), do: query

  defp maybe_filter_journal_track(query, track_id) do
    Ash.Query.filter(query, track_id == ^track_id)
  end

  defp maybe_filter_journal_item(query, nil), do: query

  defp maybe_filter_journal_item(query, item_id) do
    Ash.Query.filter(query, event_item_links.item_id == ^item_id)
  end

  defp maybe_filter_journal_event_type(query, nil), do: query

  defp maybe_filter_journal_event_type(query, event_type_id) do
    Ash.Query.filter(query, event_type_id == ^event_type_id)
  end

  defp maybe_filter_journal_status(query, nil), do: query

  defp maybe_filter_journal_status(query, status) do
    Ash.Query.filter(query, status == ^status)
  end

  defp maybe_filter_older_than(query, nil), do: query

  defp maybe_filter_older_than(query, cursor) do
    Ash.Query.filter(
      query,
      effective_at < ^cursor.effective_at or
        (effective_at == ^cursor.effective_at and recorded_at < ^cursor.recorded_at) or
        (effective_at == ^cursor.effective_at and recorded_at == ^cursor.recorded_at and
           inserted_at < ^cursor.inserted_at) or
        (effective_at == ^cursor.effective_at and recorded_at == ^cursor.recorded_at and
           inserted_at == ^cursor.inserted_at and id < ^cursor.id)
    )
  end

  defp load_journal_page_events([], _actor), do: {:ok, []}

  defp load_journal_page_events(events, actor) do
    Ash.load(
      events,
      [
        :event_type,
        :track,
        :replaces_event_instance,
        event_item_links: [:item],
        item_effects: [:item, :replaces_item_effect]
      ],
      actor: actor
    )
  end

  defp replacement_events(_plan_id, [], _actor), do: {:ok, []}

  defp replacement_events(plan_id, events, actor) do
    event_ids = Enum.map(events, & &1.id)

    list_events(
      actor: actor,
      query: [
        filter: [plan_id: plan_id, replaces_event_instance_id: [in: event_ids]],
        sort: [effective_at: :asc, recorded_at: :asc, inserted_at: :asc, id: :asc]
      ]
    )
  end

  defp next_journal_cursor(events, true), do: events |> List.last() |> Map.fetch!(:id)
  defp next_journal_cursor(_events, false), do: nil

  defp journal_sort(nil), do: [effective_at: :asc, recorded_at: :asc, inserted_at: :asc]
  defp journal_sort(_limit), do: [effective_at: :desc, recorded_at: :desc, inserted_at: :desc]

  defp maybe_add_limit(query_opts, nil), do: query_opts
  defp maybe_add_limit(query_opts, limit), do: Keyword.put(query_opts, :limit, limit)

  def read_journal!(plan_or_id, opts) do
    case read_journal(plan_or_id, opts) do
      {:ok, events} -> events
      {:error, error} -> raise error
    end
  end

  def item_history(item_or_id, opts) do
    actor = Keyword.fetch!(opts, :actor)
    item_id = id(item_or_id)

    with {:ok, links} <- list_event_item_links(actor: actor, query: [filter: [item_id: item_id]]),
         {:ok, links} <- Ash.load(links, :event_instance, actor: actor) do
      links
      |> Enum.map(& &1.event_instance)
      |> Enum.sort_by(&DateTime.to_unix(&1.effective_at, :microsecond))
      |> then(&{:ok, &1})
    end
  end

  def item_history!(item_or_id, opts) do
    case item_history(item_or_id, opts) do
      {:ok, events} -> events
      {:error, error} -> raise error
    end
  end

  def get_item_state(item, opts) do
    actor = Keyword.fetch!(opts, :actor)

    with {:ok, item} <- Plans.get_item(id(item), actor: actor),
         {:ok, item} <- Ash.load(item, [item_effects: [:event_instance]], actor: actor) do
      {:ok,
       Improve.Planning.ItemState.calculate(
         item,
         sort_item_effects(item.item_effects),
         Keyword.take(opts, [:future_quantity_required])
       )}
    end
  end

  defp sort_item_effects(effects) do
    Enum.sort_by(effects, fn effect ->
      event = effect.event_instance
      {event.effective_at, event.recorded_at, effect.inserted_at, effect.id}
    end)
  end

  def get_item_state!(item, opts) do
    case get_item_state(item, opts) do
      {:ok, state} -> state
      {:error, error} -> raise error
    end
  end

  defp effect_specs(event_type, payload, item_links) do
    result =
      EffectRuleInterpreter.interpret(%{
        rules: Map.get(event_type.effect_rules, "rules", []),
        item_links: item_links,
        payload: payload
      })

    case result.diagnostics do
      [] -> result.effects
      diagnostics -> raise Enum.join(diagnostics, " ")
    end
  end

  defp persist_log_event_command!(command, actor, opts) do
    case prepare_log_event_command(command, actor) do
      {:duplicate, result} ->
        result

      {:new, event_type} ->
        create_log_event_command!(command, actor, event_type, opts)

      {:error, diagnostics} ->
        raise Enum.join(diagnostics, " ")
    end
  end

  defp prepare_log_event_command(command, actor) do
    if duplicate = existing_idempotent_log(command, actor) do
      {:duplicate, duplicate}
    else
      with {:ok, event_type} <- Plans.get_event_type(command.event_type_id, actor: actor),
           [] <- EventContract.validate(event_type, command) do
        {:new, event_type}
      else
        diagnostics when is_list(diagnostics) -> {:error, diagnostics}
        {:error, error} -> {:error, error}
      end
    end
  end

  defp create_log_event_command!(command, actor, event_type, opts) do
    event =
      create!(
        __MODULE__,
        :log_event!,
        actor,
        LogEventCommand.to_event_attrs(command)
      )

    event_item_links =
      Enum.map(
        command.item_links,
        &create_event_item_link_from_command!(&1, command, event, actor)
      )

    effect_specs = effect_specs(event_type, command.payload, command.item_links)
    replaces_item_effects = Keyword.get(opts, :replaces_item_effects, [])

    item_effects =
      effect_specs
      |> Enum.with_index()
      |> Enum.map(fn {spec, index} ->
        create_item_effect_from_spec!(spec, command.plan_id, event, actor,
          replaces_item_effect_id:
            replacement_effect_id(spec, index, command, replaces_item_effects)
        )
      end)

    slot_result = update_linked_slot_result(command, event, actor)

    %{
      event: event,
      event_item_links: event_item_links,
      item_effects: item_effects,
      slot_result: slot_result,
      idempotency_status: :accepted
    }
  end

  defp existing_idempotent_log(%{idempotency: nil}, _actor), do: nil

  defp existing_idempotent_log(command, actor) do
    command
    |> idempotency_queries()
    |> Enum.find_value(fn filters ->
      case list_events(actor: actor, query: [filter: filters, limit: 1]) do
        {:ok, [event | _]} -> existing_log_result(event, actor)
        {:ok, []} -> nil
      end
    end)
  end

  defp idempotency_queries(%{plan_id: plan_id, idempotency: idempotency}) do
    base_filters = [
      plan_id: plan_id,
      client_device_id: idempotency.client_device_id
    ]

    []
    |> maybe_add_filter(base_filters, :client_operation_id, idempotency.client_operation_id)
    |> maybe_add_filter(base_filters, :idempotency_key, idempotency.idempotency_key)
  end

  defp maybe_add_filter(filters, _base_filters, _field, nil), do: filters
  defp maybe_add_filter(filters, _base_filters, _field, ""), do: filters

  defp maybe_add_filter(filters, base_filters, field, value) do
    filters ++ [Keyword.put(base_filters, field, value)]
  end

  defp existing_log_result(event, actor) do
    event_item_links =
      list_event_item_links!(
        actor: actor,
        query: [filter: [event_instance_id: event.id]]
      )

    item_effects =
      list_item_effects!(
        actor: actor,
        query: [filter: [event_instance_id: event.id]]
      )

    slot_result =
      case event.slot_result_id do
        nil -> nil
        slot_result_id -> Sessions.get_slot_result!(slot_result_id, actor: actor)
      end

    %{
      event: event,
      event_item_links: event_item_links,
      item_effects: item_effects,
      slot_result: slot_result,
      idempotency_status: :duplicate
    }
  end

  defp replacement_effect_id(_spec, _index, %{replaces_item_effect_id: id}, _effects)
       when not is_nil(id) do
    id
  end

  defp replacement_effect_id(spec, index, _command, original_effects) do
    original_effects
    |> Enum.find(fn effect ->
      effect.item_id == spec.item_id and effect.effect_type == spec.effect_type
    end)
    |> case do
      %{id: id} -> id
      nil -> original_effects |> Enum.at(index) |> effect_id()
    end
  end

  defp effect_id(%{id: id}), do: id
  defp effect_id(_effect), do: nil

  defp linked_item_event_command_attrs(attrs, plan, event_type, linked_item, role, opts \\ []) do
    quantity = Map.get(attrs, :quantity) || Map.get(attrs, :amount)
    unit = Map.fetch!(attrs, :unit)

    %{
      plan_id: plan.id,
      event_type_id: event_type.id,
      effective_at: Map.fetch!(attrs, :effective_at),
      recorded_at: Map.fetch!(attrs, :recorded_at),
      summary: Map.get(attrs, :summary, Keyword.get(opts, :default_summary, "Event recorded")),
      quantity: quantity,
      unit: unit,
      payload: linked_item_event_payload(attrs, quantity, unit),
      note: Map.get(attrs, :note) || Map.get(attrs, :notes),
      idempotency: Map.get(attrs, :idempotency),
      replaces_event_instance_id: Keyword.get(opts, :replaces_event_instance_id),
      replaces_item_effect_id: Keyword.get(opts, :replaces_item_effect_id),
      item_links: [
        %{
          role: role,
          item_id: linked_item.id,
          metadata: Keyword.get(opts, :link_metadata, %{})
        }
      ]
    }
  end

  defp linked_item_event_payload(attrs, quantity, unit) do
    attrs
    |> Map.get(:payload, %{})
    |> Map.put_new("amount", quantity)
    |> Map.put_new("unit", unit)
  end

  defp create_item_effect_from_spec!(spec, plan_or_id, event, actor, opts) do
    create!(
      __MODULE__,
      :create_item_effect!,
      actor,
      %{
        plan_id: id(plan_or_id),
        item_id: Map.fetch!(spec, :item_id),
        event_instance_id: event.id,
        effect_type: Map.fetch!(spec, :effect_type),
        quantity: Map.get(spec, :quantity),
        unit: Map.get(spec, :unit),
        payload: Map.get(spec, :payload, %{}),
        replaces_item_effect_id: Keyword.get(opts, :replaces_item_effect_id)
      }
    )
  end

  defp create_event_item_link_from_command!(item_link, command, event, actor) do
    create!(
      __MODULE__,
      :create_event_item_link!,
      actor,
      %{
        plan_id: command.plan_id,
        event_instance_id: event.id,
        item_id: item_link.item_id,
        role: item_link.role,
        metadata: item_link.metadata
      }
    )
  end

  defp update_linked_slot_result(%{slot_result_id: nil}, _event, _actor), do: nil

  defp update_linked_slot_result(%{item_links: []}, _event, _actor), do: nil

  defp update_linked_slot_result(
         %{replaces_event_instance_id: original_event_id} = command,
         event,
         actor
       )
       when not is_nil(original_event_id) do
    slot_result = Sessions.get_slot_result!(command.slot_result_id, actor: actor)

    create!(
      Sessions,
      :correct_slot_result!,
      actor,
      slot_result,
      %{
        actual_payload: command.payload,
        event_instance_id: event.id,
        expected_event_instance_id: original_event_id,
        notes: command.note
      }
    )
  end

  defp update_linked_slot_result(command, event, actor) do
    slot_result = Sessions.get_slot_result!(command.slot_result_id, actor: actor)
    [%{item_id: item_id} | _] = command.item_links
    update_slot_result!(slot_result, item_id, command, event, actor)
  end

  defp update_slot_result!(slot_result, %{id: item_id}, command, event, actor) do
    update_slot_result!(slot_result, item_id, command, event, actor)
  end

  defp update_slot_result!(slot_result, item_id, command, event, actor) do
    function =
      if slot_result.recommended_item_id == item_id do
        :complete_slot_result!
      else
        :swap_slot_result!
      end

    create!(
      Sessions,
      function,
      actor,
      slot_result,
      %{
        actual_item_id: item_id,
        actual_payload: command.payload,
        event_instance_id: event.id,
        notes: command.note
      }
    )
  end

  defp create!(domain, function, actor, attrs) do
    {record, notifications} =
      apply(domain, function, [
        attrs,
        [actor: actor, return_notifications?: true]
      ])

    collect_notifications!(notifications)
    record
  end

  defp create!(domain, function, actor, record, attrs) do
    {updated_record, notifications} =
      apply(domain, function, [
        record,
        attrs,
        [actor: actor, return_notifications?: true]
      ])

    collect_notifications!(notifications)
    updated_record
  end

  defp id(%{id: id}), do: id
  defp id(id), do: id

  defp fetch_plan(%{id: id}, actor), do: Plans.get_plan(id, actor: actor)
  defp fetch_plan(id, actor), do: Plans.get_plan(id, actor: actor)

  defp reset_notifications! do
    Process.put(@notifications_key, [])
  end

  defp collect_notifications!(notifications) do
    Process.put(@notifications_key, Process.get(@notifications_key, []) ++ notifications)
  end

  defp take_notifications! do
    notifications = Process.get(@notifications_key, [])
    Process.delete(@notifications_key)
    notifications
  end
end
