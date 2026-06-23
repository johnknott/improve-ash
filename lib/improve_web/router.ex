defmodule ImproveWeb.Router do
  use ImproveWeb, :router

  import ImproveWeb.AuthPlug

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :load_from_session
  end

  scope "/api", ImproveWeb do
    pipe_through :api

    post "/auth/request-code", AuthController, :request_code
    post "/auth/verify-code", AuthController, :verify_code
    get "/auth/me", AuthController, :me
    post "/auth/logout", AuthController, :logout

    get "/app/dashboard", AppController, :dashboard
    post "/app/log-event", AppController, :log_event

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
