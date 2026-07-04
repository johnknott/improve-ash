defmodule ImproveWeb.ApiError do
  @moduledoc """
  The single JSON error envelope for the whole API.

  Every error response renders as:

      %{error: %{code: "...", message: "...", details: [%{field: ..., message: "..."}]}}

  `code` is a stable machine-readable string (`unauthenticated`, `not_found`,
  `validation_failed`, `rate_limited`, `invalid_request`, `request_failed`,
  `internal_error`). `message` is a human-readable summary. `details` carries
  field-level validation errors where known; `field` is nil for errors that
  don't map to a single input.
  """

  def payload(code, message, details \\ []) do
    %{error: %{code: code, message: message, details: Enum.map(details, &detail/1)}}
  end

  @doc """
  Builds the envelope from a list of validation diagnostics, which may be
  plain strings or `%{field: ..., message: ...}` maps.
  """
  def validation_payload(diagnostics) do
    payload("validation_failed", join_messages(diagnostics), diagnostics)
  end

  def join_messages(diagnostics) do
    diagnostics
    |> Enum.map(&detail/1)
    |> Enum.map_join(" ", & &1.message)
  end

  defp detail(%{field: field, message: message}), do: %{field: field, message: message}
  defp detail(message) when is_binary(message), do: %{field: nil, message: message}
  defp detail(other), do: %{field: nil, message: inspect(other)}
end
