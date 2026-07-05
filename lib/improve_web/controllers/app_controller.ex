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

  def log_track(conn, params) do
    call_app(conn, params, &UiApi.log_track/2,
      not_found_message: "That track is not available.",
      fallback_status: 422,
      fallback_message: "We could not log that track."
    )
  end

  def skip_track(conn, params) do
    call_app(conn, params, &UiApi.skip_track/2,
      not_found_message: "That track is not available.",
      fallback_status: 422,
      fallback_message: "We could not skip that track."
    )
  end

  def skip_session_slot(conn, params) do
    call_app(conn, params, &UiApi.skip_session_slot/2,
      not_found_message: "That session slot is not available.",
      fallback_status: 422,
      fallback_message: "We could not skip that slot."
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

  def submit_offline_events(conn, params) do
    call_app(conn, params, &UiApi.submit_offline_events/2,
      fallback_status: 422,
      fallback_message: "We could not submit your offline events."
    )
  end

  def list_proposals(conn, params) do
    call_app(conn, params, &UiApi.list_proposals/2,
      not_found_message: "That plan is not available.",
      fallback_status: 422,
      fallback_message: "We could not load proposals."
    )
  end

  def approve_proposal(conn, params) do
    call_app(conn, params, &UiApi.approve_proposal/2,
      not_found_message: "That proposal is not available.",
      fallback_status: 422,
      fallback_message: "We could not approve that proposal."
    )
  end

  def dismiss_proposal(conn, params) do
    call_app(conn, params, &UiApi.dismiss_proposal/2,
      not_found_message: "That proposal is not available.",
      fallback_status: 422,
      fallback_message: "We could not dismiss that proposal."
    )
  end

  def create_plan(conn, params) do
    call_app(conn, params, &UiApi.create_plan/2,
      fallback_status: 422,
      fallback_message: "We could not create that plan."
    )
  end

  def update_plan(conn, params) do
    call_app(conn, params, &UiApi.update_plan/2,
      not_found_message: "That plan is not available.",
      fallback_status: 422,
      fallback_message: "We could not update that plan."
    )
  end

  def create_track(conn, params) do
    call_app(conn, params, &UiApi.create_track/2,
      not_found_message: "That plan is not available.",
      fallback_status: 422,
      fallback_message: "We could not create that goal."
    )
  end

  def update_track(conn, params) do
    call_app(conn, params, &UiApi.update_track/2,
      not_found_message: "That track is not available.",
      fallback_status: 422,
      fallback_message: "We could not update that goal."
    )
  end

  def create_session_template(conn, params) do
    call_app(conn, params, &UiApi.create_session_template/2,
      not_found_message: "That plan is not available.",
      fallback_status: 422,
      fallback_message: "We could not create that session template."
    )
  end

  def update_session_template(conn, params) do
    call_app(conn, params, &UiApi.update_session_template/2,
      not_found_message: "That session template is not available.",
      fallback_status: 422,
      fallback_message: "We could not update that session template."
    )
  end

  def create_session_slot(conn, params) do
    call_app(conn, params, &UiApi.create_session_slot/2,
      not_found_message: "That plan is not available.",
      fallback_status: 422,
      fallback_message: "We could not create that session slot."
    )
  end

  def update_session_slot(conn, params) do
    call_app(conn, params, &UiApi.update_session_slot/2,
      not_found_message: "That session slot is not available.",
      fallback_status: 422,
      fallback_message: "We could not update that session slot."
    )
  end

  def create_item(conn, params) do
    call_app(conn, params, &UiApi.create_item/2,
      not_found_message: "That plan is not available.",
      fallback_status: 422,
      fallback_message: "We could not create that item."
    )
  end

  def update_item(conn, params) do
    call_app(conn, params, &UiApi.update_item/2,
      not_found_message: "That item is not available.",
      fallback_status: 422,
      fallback_message: "We could not update that item."
    )
  end

  def create_item_type(conn, params) do
    call_app(conn, params, &UiApi.create_item_type/2,
      not_found_message: "That plan is not available.",
      fallback_status: 422,
      fallback_message: "We could not create that item type."
    )
  end

  def update_item_type(conn, params) do
    call_app(conn, params, &UiApi.update_item_type/2,
      not_found_message: "That item type is not available.",
      fallback_status: 422,
      fallback_message: "We could not update that item type."
    )
  end

  def create_event_type(conn, params) do
    call_app(conn, params, &UiApi.create_event_type/2,
      not_found_message: "That plan is not available.",
      fallback_status: 422,
      fallback_message: "We could not create that event type."
    )
  end

  def update_event_type(conn, params) do
    call_app(conn, params, &UiApi.update_event_type/2,
      not_found_message: "That event type is not available.",
      fallback_status: 422,
      fallback_message: "We could not update that event type."
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
        app_error(conn, 401, "unauthenticated", "Please sign in to continue.")

      {:error, :unknown_demo_plan} ->
        app_error(conn, 422, "invalid_request", "Choose a demo plan to install.")

      {:error, :not_found} ->
        app_error(
          conn,
          404,
          "not_found",
          Keyword.get(opts, :not_found_message, "That resource is not available.")
        )

      {:error, diagnostics} when is_list(diagnostics) ->
        conn
        |> put_status(422)
        |> json(ImproveWeb.ApiError.validation_payload(diagnostics))

      {:error, _error} ->
        app_error(
          conn,
          Keyword.fetch!(opts, :fallback_status),
          "request_failed",
          Keyword.fetch!(opts, :fallback_message)
        )
    end
  end

  defp current_actor(%{assigns: %{current_user: actor}}) when not is_nil(actor), do: {:ok, actor}
  defp current_actor(_conn), do: {:error, :unauthenticated}

  defp app_error(conn, status, code, message) do
    conn
    |> put_status(status)
    |> json(ImproveWeb.ApiError.payload(code, message))
  end
end
