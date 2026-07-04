defmodule ImproveWeb.ErrorJSON do
  @moduledoc """
  Renders framework-level errors (unknown routes, crashes) in the same
  envelope as controller errors. See `ImproveWeb.ApiError`.
  """

  def render(template, _assigns) do
    ImproveWeb.ApiError.payload(
      code_for(template),
      Phoenix.Controller.status_message_from_template(template)
    )
  end

  defp code_for("404" <> _rest), do: "not_found"
  defp code_for("401" <> _rest), do: "unauthenticated"
  defp code_for("429" <> _rest), do: "rate_limited"
  defp code_for("500" <> _rest), do: "internal_error"
  defp code_for("4" <> _rest), do: "invalid_request"
  defp code_for(_template), do: "internal_error"
end
