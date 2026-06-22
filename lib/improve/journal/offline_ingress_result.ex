defmodule Improve.Journal.OfflineIngressResult do
  @moduledoc """
  Per-command result returned by offline journal batch ingress.

  Results are deliberately small and stable so clients can clear accepted or
  duplicate pending logs while keeping rejected or resolution-needed logs in the
  local outbox for user attention.
  """

  @statuses [:accepted, :duplicate, :rejected, :needs_resolution]

  @enforce_keys [:index, :status]
  defstruct [
    :index,
    :status,
    :client_operation_id,
    :idempotency_key,
    :event_instance_id,
    :conflict_category,
    diagnostics: []
  ]

  def accepted(index, attrs, log_result) do
    %__MODULE__{
      index: index,
      status: status(log_result),
      client_operation_id: client_operation_id(attrs),
      idempotency_key: idempotency_key(attrs),
      event_instance_id: log_result.event.id
    }
  end

  def rejected(index, attrs, diagnostics, conflict_category \\ :invalid_payload) do
    %__MODULE__{
      index: index,
      status: :rejected,
      client_operation_id: client_operation_id(attrs),
      idempotency_key: idempotency_key(attrs),
      diagnostics: List.wrap(diagnostics),
      conflict_category: conflict_category
    }
  end

  def needs_resolution(index, attrs, diagnostics, conflict_category) do
    %__MODULE__{
      index: index,
      status: :needs_resolution,
      client_operation_id: client_operation_id(attrs),
      idempotency_key: idempotency_key(attrs),
      diagnostics: List.wrap(diagnostics),
      conflict_category: conflict_category
    }
  end

  def valid_status?(status), do: status in @statuses

  defp status(%{idempotency_status: :duplicate}), do: :duplicate
  defp status(_log_result), do: :accepted

  defp client_operation_id(attrs) do
    attrs
    |> idempotency_attrs()
    |> value(:client_operation_id)
  end

  defp idempotency_key(attrs) do
    attrs
    |> idempotency_attrs()
    |> value(:idempotency_key)
  end

  defp idempotency_attrs(attrs), do: value(attrs, :idempotency, %{})

  defp value(map, key, default \\ nil)

  defp value(map, key, default) when is_map(map) do
    Map.get(map, key, Map.get(map, Atom.to_string(key), default))
  end

  defp value(_other, _key, default), do: default
end
