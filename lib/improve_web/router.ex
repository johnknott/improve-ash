defmodule ImproveWeb.Router do
  use ImproveWeb, :router

  import ImproveWeb.AuthPlug

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :load_from_session
    plug :load_from_bearer
  end

  scope "/api", ImproveWeb do
    pipe_through :api

    post "/auth/request-code", AuthController, :request_code
    post "/auth/verify-code", AuthController, :verify_code
    get "/auth/me", AuthController, :me
    post "/auth/profile", AuthController, :complete_profile
    post "/auth/logout", AuthController, :logout
    post "/auth/refresh-token", AuthController, :refresh_token
    post "/auth/revoke-token", AuthController, :revoke_token

    get "/app/dashboard", AppController, :dashboard
    post "/app/plans", AppController, :create_plan
    patch "/app/plans/:plan_id", AppController, :update_plan
    post "/app/tracks", AppController, :create_track
    patch "/app/tracks/:track_id", AppController, :update_track
    post "/app/session-templates", AppController, :create_session_template
    patch "/app/session-templates/:session_template_id", AppController, :update_session_template
    post "/app/session-slots", AppController, :create_session_slot
    patch "/app/session-slots/:session_slot_id", AppController, :update_session_slot
    post "/app/items", AppController, :create_item
    patch "/app/items/:item_id", AppController, :update_item
    post "/app/item-types", AppController, :create_item_type
    patch "/app/item-types/:item_type_id", AppController, :update_item_type
    post "/app/event-types", AppController, :create_event_type
    patch "/app/event-types/:event_type_id", AppController, :update_event_type
    post "/app/demo-plans", AppController, :install_demo_plan
    post "/app/start-session", AppController, :start_session
    post "/app/log-session-slot", AppController, :log_session_slot
    post "/app/swap-session-slot", AppController, :swap_session_slot
    post "/app/complete-session", AppController, :complete_session
    post "/app/skip-session", AppController, :skip_session
    post "/app/log-event", AppController, :log_event
    post "/app/log-linked-event", AppController, :log_linked_event
    post "/app/correct-linked-event", AppController, :correct_linked_event
    post "/app/offline-events", AppController, :submit_offline_events
    get "/app/proposals", AppController, :list_proposals
    post "/app/proposals/approve", AppController, :approve_proposal
    post "/app/proposals/dismiss", AppController, :dismiss_proposal

    post "/rpc/run", AshTypescriptRpcController, :run
    post "/rpc/validate", AshTypescriptRpcController, :validate
  end

  if Application.compile_env(:improve, :dev_routes, false) do
    scope "/dev", ImproveWeb do
      pipe_through :api

      get "/mailbox/latest-otp", DevMailboxController, :latest_otp
    end
  end
end
