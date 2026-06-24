defmodule Improve.Planning.PlanDraftImporter do
  @moduledoc """
  Imports portable stable-key drafts into persisted, user-owned plan records.
  """

  alias Improve.Planning.Diagnostics
  alias Improve.Planning.PlanDraft
  alias Improve.Plans
  alias Improve.Repo

  @notifications_key {__MODULE__, :notifications}

  def import_draft(draft, opts) do
    actor = Keyword.fetch!(opts, :actor)
    draft = PlanDraft.normalize(draft)
    diagnostics = Diagnostics.validate_plan_draft(draft) ++ import_date_diagnostics(draft)

    case diagnostics do
      [] ->
        draft
        |> persist(actor, opts)
        |> case do
          {:ok, result} -> {:ok, result}
          {:error, error} -> {:error, error}
        end

      diagnostics ->
        {:error, diagnostics}
    end
  end

  def import_draft!(draft, opts) do
    case import_draft(draft, opts) do
      {:ok, result} ->
        result

      {:error, diagnostics} when is_list(diagnostics) ->
        raise ArgumentError, diagnostics_text(diagnostics)

      {:error, error} ->
        raise error
    end
  end

  defp persist(draft, actor, opts) do
    Repo.transaction(fn ->
      reset_notifications!()

      plan =
        create!(
          :create_plan!,
          actor,
          %{
            name: value(draft, :name),
            intention: value(draft, :intention) || "",
            starts_on: date!(value(draft, :starts_on)),
            ends_on: date!(value(draft, :ends_on)),
            status: Keyword.get(opts, :status, :draft),
            source_kind: :imported,
            source_key: value(draft, :key)
          }
        )

      item_types = create_item_types!(draft, plan, actor)
      items = create_items!(draft, plan, item_types, actor)
      pools = create_pools!(draft, plan, actor)
      create_pool_memberships!(draft, plan, pools, items, actor)
      environments = create_environments!(draft, plan, items, actor)
      event_types = create_event_types!(draft, plan, actor)
      session_templates = create_session_templates!(draft, plan, environments, actor)
      create_session_slots!(draft, plan, session_templates, pools, actor)
      tracks = create_tracks!(draft, plan, event_types, actor)
      schedules = create_schedules!(draft, plan, session_templates, tracks, actor)

      result = %{
        plan: plan,
        item_types: item_types,
        items: items,
        pools: pools,
        environments: environments,
        event_types: event_types,
        session_templates: session_templates,
        tracks: tracks,
        schedules: schedules
      }

      {result, take_notifications!()}
    end)
    |> case do
      {:ok, {result, notifications}} ->
        Ash.Notifier.notify(notifications)
        {:ok, result}

      {:error, error} ->
        {:error, error}
    end
  end

  defp create_item_types!(draft, plan, actor) do
    draft
    |> list(:item_types)
    |> Enum.map(fn item_type ->
      create!(
        :create_item_type!,
        actor,
        %{
          plan_id: plan.id,
          key: value(item_type, :key),
          name: value(item_type, :name),
          description: value(item_type, :description),
          facts_schema: value(item_type, :facts_schema) || %{},
          display_hints: value(item_type, :display_hints) || %{}
        }
      )
    end)
    |> by_key()
  end

  defp create_items!(draft, plan, item_types, actor) do
    draft
    |> list(:items)
    |> Enum.map(fn item ->
      create!(
        :create_item!,
        actor,
        %{
          plan_id: plan.id,
          item_type_id: Map.fetch!(item_types, value(item, :item_type_key)).id,
          key: value(item, :key),
          name: value(item, :name),
          facts: value(item, :facts) || %{},
          stateful: truthy?(value(item, :stateful))
        }
      )
    end)
    |> by_key()
  end

  defp create_pools!(draft, plan, actor) do
    draft
    |> list(:pools)
    |> Enum.map(fn pool ->
      create!(
        :create_pool!,
        actor,
        %{
          plan_id: plan.id,
          key: value(pool, :key),
          name: value(pool, :name),
          description: value(pool, :description)
        }
      )
    end)
    |> by_key()
  end

  defp create_pool_memberships!(draft, plan, pools, items, actor) do
    draft
    |> list(:pools)
    |> Enum.flat_map(fn pool ->
      pool
      |> list(:item_keys)
      |> Enum.map(fn item_key ->
        create!(
          :create_pool_membership!,
          actor,
          %{
            plan_id: plan.id,
            pool_id: Map.fetch!(pools, value(pool, :key)).id,
            item_id: Map.fetch!(items, item_key).id
          }
        )
      end)
    end)
  end

  defp create_environments!(draft, plan, items, actor) do
    draft
    |> list(:environments)
    |> Enum.map(fn environment ->
      available_item_ids =
        environment
        |> list(:available_item_keys)
        |> Enum.map(&Map.fetch!(items, &1).id)

      create!(
        :create_environment!,
        actor,
        %{
          plan_id: plan.id,
          key: value(environment, :key),
          name: value(environment, :name),
          description: value(environment, :description),
          available_item_ids: available_item_ids
        }
      )
    end)
    |> by_key()
  end

  defp create_event_types!(draft, plan, actor) do
    draft
    |> list(:event_types)
    |> Enum.map(fn event_type ->
      create!(
        :create_event_type!,
        actor,
        %{
          plan_id: plan.id,
          key: value(event_type, :key),
          name: value(event_type, :name),
          description: value(event_type, :description),
          payload_schema: value(event_type, :payload_schema) || %{},
          item_link_roles: value(event_type, :item_link_roles) || %{},
          effect_rules: value(event_type, :effect_rules) || %{}
        }
      )
    end)
    |> by_key()
  end

  defp create_session_templates!(draft, plan, environments, actor) do
    draft
    |> list(:session_templates)
    |> Enum.map(fn template ->
      create!(
        :create_session_template!,
        actor,
        %{
          plan_id: plan.id,
          key: value(template, :key),
          name: value(template, :name),
          description: value(template, :description),
          environment_id: referenced_id(environments, value(template, :environment_key)),
          completion_policy: value(template, :completion_policy) || %{},
          missed_policy: value(template, :missed_policy) || %{}
        }
      )
    end)
    |> by_key()
  end

  defp create_session_slots!(draft, plan, session_templates, pools, actor) do
    draft
    |> list(:session_templates)
    |> Enum.flat_map(fn template ->
      template_record = Map.fetch!(session_templates, value(template, :key))

      template
      |> list(:slots)
      |> Enum.map(fn slot ->
        create!(
          :create_session_slot!,
          actor,
          %{
            plan_id: plan.id,
            session_template_id: template_record.id,
            key: value(slot, :key),
            name: value(slot, :name),
            pool_id: Map.fetch!(pools, value(slot, :pool_key)).id,
            count: value(slot, :count) || 1,
            optional: truthy?(value(slot, :optional)),
            rules: value(slot, :rules) || %{},
            position: value(slot, :position) || 0
          }
        )
      end)
    end)
  end

  defp create_tracks!(draft, plan, event_types, actor) do
    draft
    |> list(:tracks)
    |> Enum.map(fn track ->
      create!(
        :create_track!,
        actor,
        %{
          plan_id: plan.id,
          key: value(track, :key),
          name: value(track, :name),
          description: value(track, :description),
          event_type_id: Map.fetch!(event_types, value(track, :event_type_key)).id,
          target: value(track, :target) || %{},
          completion_policy: value(track, :completion_policy) || %{},
          missed_policy: value(track, :missed_policy) || %{}
        }
      )
    end)
    |> by_key()
  end

  defp create_schedules!(draft, plan, session_templates, tracks, actor) do
    draft
    |> list(:schedules)
    |> Enum.map(fn schedule ->
      create!(
        :create_schedule!,
        actor,
        %{
          plan_id: plan.id,
          owner_type: owner_type(value(schedule, :owner_type)),
          owner_id: owner_id(schedule, session_templates, tracks),
          kind: schedule_kind(value(schedule, :kind)),
          rules: value(schedule, :rules) || %{},
          starts_on: date!(value(schedule, :starts_on)),
          ends_on: date(value(schedule, :ends_on))
        }
      )
    end)
  end

  defp import_date_diagnostics(draft) do
    []
    |> maybe_add(
      blank?(value(draft, :starts_on)),
      :missing_plan_date,
      "Imported draft must include starts_on.",
      %{
        field: "starts_on"
      }
    )
    |> maybe_add(
      blank?(value(draft, :ends_on)),
      :missing_plan_date,
      "Imported draft must include ends_on.",
      %{
        field: "ends_on"
      }
    )
  end

  defp maybe_add(diagnostics, false, _code, _message, _details), do: diagnostics

  defp maybe_add(diagnostics, true, code, message, details),
    do: diagnostic(diagnostics, code, message, details)

  defp diagnostic(diagnostics, code, message, details) do
    diagnostics ++
      [
        %{
          severity: :error,
          code: code,
          message: message,
          path: [],
          ref: Map.get(details, :ref),
          details: details
        }
      ]
  end

  defp owner_id(schedule, session_templates, tracks) do
    case owner_type(value(schedule, :owner_type)) do
      :session_template -> Map.fetch!(session_templates, value(schedule, :owner_key)).id
      :track -> Map.fetch!(tracks, value(schedule, :owner_key)).id
    end
  end

  defp referenced_id(_records, nil), do: nil
  defp referenced_id(records, key), do: Map.fetch!(records, key).id

  defp by_key(records), do: Map.new(records, &{&1.key, &1})

  defp date!(value) do
    case date(value) do
      nil -> raise ArgumentError, "Expected draft date, got #{inspect(value)}"
      date -> date
    end
  end

  defp date(nil), do: nil
  defp date(%Date{} = date), do: date

  defp date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      {:error, _reason} -> nil
    end
  end

  defp date(_value), do: nil

  defp owner_type(:session_template), do: :session_template
  defp owner_type("session_template"), do: :session_template
  defp owner_type(:track), do: :track
  defp owner_type("track"), do: :track
  defp owner_type(_owner_type), do: nil

  defp schedule_kind(kind) when is_atom(kind), do: kind

  defp schedule_kind(kind) when is_binary(kind) do
    String.to_existing_atom(kind)
  rescue
    ArgumentError -> nil
  end

  defp schedule_kind(_kind), do: nil

  defp list(source, key) do
    source
    |> value(key)
    |> case do
      nil -> []
      value when is_list(value) -> value
      value -> [value]
    end
  end

  defp value(source, key) when is_map(source) and is_atom(key) do
    Map.get(source, key) || Map.get(source, Atom.to_string(key))
  end

  defp value(source, key) when is_map(source) and is_binary(key) do
    Map.get(source, key) || Map.get(source, existing_atom(key))
  end

  defp value(_source, _key), do: nil

  defp existing_atom(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end

  defp truthy?(true), do: true
  defp truthy?("true"), do: true
  defp truthy?(1), do: true
  defp truthy?(_value), do: false

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?([]), do: true
  defp blank?(_value), do: false

  defp create!(function, actor, attrs) do
    {record, notifications} =
      apply(Plans, function, [
        attrs,
        [actor: actor, return_notifications?: true]
      ])

    collect_notifications!(notifications)
    record
  end

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

  defp diagnostics_text(diagnostics) do
    diagnostics
    |> Enum.map(& &1.message)
    |> Enum.join(" ")
  end
end
