defmodule Improve.Journal.LogEventCommand do
  @moduledoc """
  Normalized command input for generic event logging.

  This struct is the boundary between capture/offline/RPC inputs and the future
  workflow that persists journal events. It is intentionally database-free:
  ownership, same-plan checks, effect generation, and transactions belong to the
  workflow that consumes the command.

  The shape follows `notes/full-rewrite-spec.md`: one event type, effective and
  recorded timestamps, optional planned-work links, involved item links with
  roles, structured payload, origin, and optional idempotency metadata for
  offline retries.
  """

  @origins [:manual, :seed, :assistant_proposed, :imported, :offline_sync]

  defstruct [
    :plan_id,
    :event_type_id,
    :effective_at,
    :recorded_at,
    :summary,
    :quantity,
    :unit,
    :note,
    :session_occurrence_id,
    :slot_result_id,
    :direct_goal_id,
    :replaces_event_instance_id,
    :replaces_item_effect_id,
    payload: %{},
    origin: :manual,
    item_links: [],
    idempotency: nil
  ]

  defmodule ItemLink do
    @moduledoc "A role-qualified item link included in a generic event log command."
    defstruct [:role, :item_id, metadata: %{}]
  end

  defmodule Idempotency do
    @moduledoc "Client-origin metadata used to make offline event retries safe."
    defstruct [:client_event_id, :client_operation_id, :client_device_id, :idempotency_key]
  end

  def from_attrs(attrs) when is_map(attrs) do
    command = %__MODULE__{
      plan_id: value(attrs, :plan_id),
      event_type_id: value(attrs, :event_type_id),
      effective_at: value(attrs, :effective_at),
      recorded_at: value(attrs, :recorded_at),
      summary: value(attrs, :summary),
      quantity: value(attrs, :quantity),
      unit: value(attrs, :unit),
      note: value(attrs, :note),
      payload: value(attrs, :payload, %{}),
      origin: normalize_origin(value(attrs, :origin, :manual)),
      session_occurrence_id: value(attrs, :session_occurrence_id),
      slot_result_id: value(attrs, :slot_result_id),
      direct_goal_id: value(attrs, :direct_goal_id),
      replaces_event_instance_id: value(attrs, :replaces_event_instance_id),
      replaces_item_effect_id: value(attrs, :replaces_item_effect_id),
      item_links: normalize_item_links(value(attrs, :item_links, [])),
      idempotency: normalize_idempotency(value(attrs, :idempotency))
    }

    diagnostics = diagnostics(command)

    case diagnostics do
      [] -> {:ok, command}
      diagnostics -> {:error, diagnostics}
    end
  end

  def from_attrs(_attrs), do: {:error, ["Event log command must be a map."]}

  def from_attrs!(attrs) do
    case from_attrs(attrs) do
      {:ok, command} -> command
      {:error, diagnostics} -> raise ArgumentError, Enum.join(diagnostics, " ")
    end
  end

  def to_event_attrs(%__MODULE__{} = command) do
    command
    |> Map.from_struct()
    |> Map.drop([:item_links, :idempotency, :replaces_item_effect_id])
    |> Map.merge(idempotency_attrs(command.idempotency))
  end

  defp diagnostics(command) do
    []
    |> require_field(command, :plan_id, "Plan is required.")
    |> require_field(command, :event_type_id, "Event type is required.")
    |> require_field(command, :effective_at, "Effective time is required.")
    |> require_field(command, :recorded_at, "Recorded time is required.")
    |> require_field(command, :summary, "Summary is required.")
    |> validate_origin(command)
    |> validate_item_links(command)
    |> validate_idempotency(command)
  end

  defp require_field(diagnostics, command, field, message) do
    if blank?(Map.fetch!(command, field)) do
      diagnostics ++ [message]
    else
      diagnostics
    end
  end

  defp validate_origin(diagnostics, command) do
    if command.origin in @origins do
      diagnostics
    else
      diagnostics ++ ["Origin #{inspect(command.origin)} is not supported."]
    end
  end

  defp validate_item_links(diagnostics, command) do
    command.item_links
    |> Enum.with_index(1)
    |> Enum.reduce(diagnostics, fn
      {%ItemLink{role: role, item_id: item_id}, index}, diagnostics ->
        diagnostics
        |> maybe_add(blank?(role), "Item link #{index} role is required.")
        |> maybe_add(blank?(item_id), "Item link #{index} item is required.")

      {_other, index}, diagnostics ->
        diagnostics ++ ["Item link #{index} must be a map."]
    end)
  end

  defp validate_idempotency(diagnostics, %{idempotency: nil}), do: diagnostics

  defp validate_idempotency(diagnostics, %{idempotency: %Idempotency{} = idempotency}) do
    diagnostics
    |> maybe_add(
      blank?(idempotency.client_device_id),
      "Idempotency requires a client device ID."
    )
    |> maybe_add(
      blank?(idempotency.client_operation_id) and blank?(idempotency.idempotency_key),
      "Idempotency requires a client operation ID or idempotency key."
    )
  end

  defp validate_idempotency(diagnostics, _command) do
    diagnostics ++ ["Idempotency metadata must be a map."]
  end

  defp normalize_item_links(item_links) when is_list(item_links) do
    Enum.map(item_links, fn
      %ItemLink{} = item_link ->
        item_link

      item_link when is_map(item_link) ->
        %ItemLink{
          role: value(item_link, :role),
          item_id: value(item_link, :item_id),
          metadata: value(item_link, :metadata, %{})
        }

      other ->
        other
    end)
  end

  defp normalize_item_links(other), do: [other]

  defp normalize_idempotency(nil), do: nil

  defp normalize_idempotency(%Idempotency{} = idempotency), do: idempotency

  defp normalize_idempotency(attrs) when is_map(attrs) do
    %Idempotency{
      client_event_id: value(attrs, :client_event_id),
      client_operation_id: value(attrs, :client_operation_id),
      client_device_id: value(attrs, :client_device_id),
      idempotency_key: value(attrs, :idempotency_key)
    }
  end

  defp normalize_idempotency(other), do: other

  defp normalize_origin(origin) when is_binary(origin) do
    Enum.find(@origins, origin, &(Atom.to_string(&1) == origin))
  end

  defp normalize_origin(origin), do: origin

  defp idempotency_attrs(nil), do: %{}

  defp idempotency_attrs(%Idempotency{} = idempotency) do
    %{
      client_event_id: idempotency.client_event_id,
      client_operation_id: idempotency.client_operation_id,
      client_device_id: idempotency.client_device_id,
      idempotency_key: idempotency.idempotency_key
    }
  end

  defp value(map, key, default \\ nil) do
    Map.get(map, key, Map.get(map, Atom.to_string(key), default))
  end

  defp maybe_add(diagnostics, true, message), do: diagnostics ++ [message]
  defp maybe_add(diagnostics, false, _message), do: diagnostics

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?([]), do: true
  defp blank?(_value), do: false
end
