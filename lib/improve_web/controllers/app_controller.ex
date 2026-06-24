defmodule ImproveWeb.AppController do
  use ImproveWeb, :controller

  alias Improve.App.UiApi

  def dashboard(conn, params) do
    call_app(conn, params, &UiApi.dashboard/2,
      fallback_status: 400,
      fallback_message: "We could not load your planning dashboard."
    )
  end

  def log_event(conn, params) do
    call_app(conn, params, &UiApi.log_event/2,
      fallback_status: 422,
      fallback_message: "We could not log that event."
    )
  end

  def log_linked_event(conn, params) do
    call_app(conn, params, &UiApi.log_linked_event/2,
      not_found_message: "That item or event type is not available.",
      fallback_status: 422,
      fallback_message: "We could not log that event."
    )
  end

  def correct_linked_event(conn, params) do
    call_app(conn, params, &UiApi.correct_linked_event/2,
      not_found_message: "That event is not available to correct.",
      fallback_status: 422,
      fallback_message: "We could not correct that event."
    )
  end

  def install_demo_plan(conn, params) do
    call_app(conn, params, &UiApi.install_demo_plan/2,
      fallback_status: 422,
      fallback_message: "We could not install that demo plan."
    )
  end

  def create_plan(conn, params) do
    call_app(conn, params, &UiApi.create_plan/2,
      fallback_status: 422,
      fallback_message: "We could not create that plan."
    )
  end

  def create_track(conn, params) do
    call_app(conn, params, &UiApi.create_track/2,
      not_found_message: "That plan is not available.",
      fallback_status: 422,
      fallback_message: "We could not create that goal."
    )
  end

  def start_session(conn, params) do
    call_app(conn, params, &UiApi.start_session/2,
      not_found_message: "That projected session is not available.",
      fallback_status: 422,
      fallback_message: "We could not start that session."
    )
  end

  def log_session_slot(conn, params) do
    call_app(conn, params, &UiApi.log_session_slot/2,
      not_found_message: "That session slot is not available.",
      fallback_status: 422,
      fallback_message: "We could not log that session slot."
    )
  end

  def swap_session_slot(conn, params) do
    call_app(conn, params, &UiApi.swap_session_slot/2,
      not_found_message: "That session slot is not available.",
      fallback_status: 422,
      fallback_message: "We could not swap that session slot."
    )
  end

  def complete_session(conn, params) do
    call_app(conn, params, &UiApi.complete_session/2,
      not_found_message: "That session is not available.",
      fallback_status: 422,
      fallback_message: "We could not update that session."
    )
  end

  def skip_session(conn, params) do
    call_app(conn, params, &UiApi.skip_session/2,
      not_found_message: "That session is not available.",
      fallback_status: 422,
      fallback_message: "We could not update that session."
    )
  end

  defp call_app(conn, params, app_function, opts) do
    with {:ok, actor} <- current_actor(conn),
         {:ok, payload} <- app_function.(actor, params) do
      json(conn, payload)
    else
      {:error, :unauthenticated} ->
        app_error(conn, 401, "Please sign in to continue.")

      {:error, :unknown_demo_plan} ->
        app_error(conn, 422, "Choose a demo plan to install.")

      {:error, :not_found} ->
        app_error(
          conn,
          404,
          Keyword.get(opts, :not_found_message, "That resource is not available.")
        )

      {:error, diagnostics} when is_list(diagnostics) ->
        app_error(conn, 422, Enum.join(diagnostics, " "))

      {:error, _error} ->
        app_error(
          conn,
          Keyword.fetch!(opts, :fallback_status),
          Keyword.fetch!(opts, :fallback_message)
        )
    end
  end

  defp current_actor(%{assigns: %{current_user: actor}}) when not is_nil(actor), do: {:ok, actor}
  defp current_actor(_conn), do: {:error, :unauthenticated}

  defp app_error(conn, status, message) do
    conn
    |> put_status(status)
    |> json(%{error: %{message: message}})
  end
end
